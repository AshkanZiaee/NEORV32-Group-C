-- ================================================================================
-- NEORV32 CPU - Co-Processor: Integer Mul Unit (RISC-V "M" Extension, MUL-family)
-- Radix-4 Booth iterative multiplier: 32x32 -> 64 in 16 iterations
-- Entity: neorv32_cpu_cp_muldiv_r4booth (to be wrapped by neorv32_cpu_cp_muldiv)
-- Notes:
--   * Handles MUL, MULH, MULHSU, MULHU via funct7=0000001 and funct3=000/001/010/011.
--   * Signedness per M-spec: MUL=U*U low32, MULH=S*S high32, MULHSU=S*U high32, MULHU=U*U high32.
--   * One-cycle valid_o in S_DONE; res_o stable during the valid pulse.
-- ================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_cpu_cp_muldiv_r4booth is
  port (
    -- global
    clk_i   : in  std_ulogic;
    rstn_i  : in  std_ulogic;

    -- control / issue
    ctrl_i  : in  ctrl_bus_t;

    -- operands
    rs1_i   : in  std_ulogic_vector(XLEN-1 downto 0);
    rs2_i   : in  std_ulogic_vector(XLEN-1 downto 0);

    -- result
    res_o   : out std_ulogic_vector(XLEN-1 downto 0);
    valid_o : out std_ulogic
  );
end neorv32_cpu_cp_muldiv_r4booth;

architecture rtl of neorv32_cpu_cp_muldiv_r4booth is

  -- funct3 encodings for MUL-family (funct7 = 0000001)
  constant F3_MUL    : std_ulogic_vector(2 downto 0) := "000";
  constant F3_MULH   : std_ulogic_vector(2 downto 0) := "001";
  constant F3_MULHSU : std_ulogic_vector(2 downto 0) := "010";
  constant F3_MULHU  : std_ulogic_vector(2 downto 0) := "011";

  -- states
  type state_t is (S_IDLE, S_RUN, S_DONE);
  signal state      : state_t := S_IDLE;

  -- decode M-group (R-type, funct7=0000001) via control bus fields
  signal is_mulgrp  : std_ulogic := '0';
  signal f3_latched : std_ulogic_vector(2 downto 0) := (others => '0');

  -- radix-4 iteration and registers
  signal iter_cnt   : unsigned(4 downto 0) := (others => '0'); -- 0..15
  signal q_reg      : std_ulogic_vector(31 downto 0) := (others => '0'); -- multiplier bitstream (LSB-first)
  signal q_m1       : std_ulogic := '0';                                   -- q(-1)
  signal q_fill     : std_ulogic := '0';                                   -- MSB fill for signed multiplier (MULH)

  -- accumulator and shifted multiplicand
  signal acc        : signed(65 downto 0) := (others => '0'); -- 66-bit signed accumulator
  signal mshift     : signed(65 downto 0) := (others => '0'); -- multiplicand << (2*i), signed

  -- prepared operands
  signal op_a_s64   : signed(63 downto 0) := (others => '0'); -- multiplicand as signed(63:0)

  -- final product and outputs
  signal prod64     : std_ulogic_vector(63 downto 0) := (others => '0');
  signal res_q      : std_ulogic_vector(31 downto 0) := (others => '0');
  signal valid_q    : std_ulogic := '0';

begin

  -- M-group decode: ALU requests CP op and funct7=0000001 (bits 11..5 of ir_funct12)
  is_mulgrp <= '1' when (ctrl_i.alu_cp_alu = '1') and
                        (ctrl_i.ir_funct12(11 downto 5) = "0000001") else '0';

  -- main FSM
  process(clk_i, rstn_i)
    variable rec  : std_ulogic_vector(2 downto 0);
    variable addv : signed(65 downto 0);
    variable a64  : signed(63 downto 0);
  begin
    if (rstn_i = '0') then
      -- async reset
      state      <= S_IDLE;
      iter_cnt   <= (others => '0');
      q_reg      <= (others => '0');
      q_m1       <= '0';
      q_fill     <= '0';
      acc        <= (others => '0');
      mshift     <= (others => '0');
      op_a_s64   <= (others => '0');
      prod64     <= (others => '0');
      res_q      <= (others => '0');
      valid_q    <= '0';

    elsif rising_edge(clk_i) then
      valid_q <= '0'; -- default

      case state is

        when S_IDLE =>
          if (is_mulgrp = '1') then
            -- latch variant
            f3_latched <= ctrl_i.ir_funct3;

            -- prepare rs1 (multiplicand) as signed(63:0) per variant and preload for first iteration
            if (ctrl_i.ir_funct3 = F3_MULH) or (ctrl_i.ir_funct3 = F3_MULHSU) then
              a64 := resize(signed(rs1_i), 64);           -- signed rs1 for MULH/MULHSU
            else
              a64 := resize(signed('0' & rs1_i), 64);     -- zero-extend rs1 for MUL/MULHU
            end if;
            op_a_s64 <= a64;
            mshift   <= resize(a64, 66);                  -- ensure first iteration sees correct M

            -- prepare rs2 (multiplier) stream and MSB fill policy
            if (ctrl_i.ir_funct3 = F3_MULH) then
              q_fill <= rs2_i(31);                        -- signed multiplier for MULH
            else
              q_fill <= '0';                              -- unsigned multiplier otherwise
            end if;
            q_reg    <= rs2_i;                            -- LSB-first consumption
            q_m1     <= '0';                              -- q(-1) = 0

            -- initialize engine
            acc      <= (others => '0');
            iter_cnt <= (others => '0');
            state    <= S_RUN;
          end if;

        when S_RUN =>
          -- radix-4 Booth recoding on {q1,q0,q-1}
          rec := q_reg(1) & q_reg(0) & q_m1;

          -- select addend: 0, ±M, ±2M
          case rec is
            when "000" | "111" => addv := (others => '0');           -- 0
            when "001" | "010" => addv := mshift;                    -- +M
            when "011"          => addv := signed(shift_left(unsigned(mshift), 1));  -- +2M
            when "100"          => addv := -signed(shift_left(unsigned(mshift), 1)); -- -2M
            when "101" | "110" => addv := -mshift;                   -- -M
            when others         => addv := (others => '0');
          end case;

          -- accumulate
          acc <= acc + addv;

          -- advance: consume two bits; remember q(-1); MSB fill (sign for MULH, zero else)
          q_m1  <= q_reg(1);
          q_reg <= q_fill & q_fill & q_reg(31 downto 2);  -- concatenation yields 32 bits

          -- shift multiplicand by 2 per step
          mshift <= signed(shift_left(unsigned(mshift), 2));

          -- finish after 16 steps
          if (iter_cnt = to_unsigned(15, iter_cnt'length)) then
            prod64 <= std_ulogic_vector(acc(63 downto 0));
            state  <= S_DONE;
          else
            iter_cnt <= iter_cnt + 1;
          end if;

        when S_DONE =>
          -- slice result per M-spec
          if    (f3_latched = F3_MUL) then
            res_q <= prod64(31 downto 0);     -- low 32 bits
          elsif (f3_latched = F3_MULH) or
                (f3_latched = F3_MULHSU) or
                (f3_latched = F3_MULHU) then
            res_q <= prod64(63 downto 32);    -- high 32 bits
          else
            res_q <= (others => '0');
          end if;

          valid_q <= '1';                      -- one-cycle strobe
          state   <= S_IDLE;

      end case;
    end if;
  end process;

  -- outputs
  res_o   <= res_q;
  valid_o <= valid_q;

end rtl;
