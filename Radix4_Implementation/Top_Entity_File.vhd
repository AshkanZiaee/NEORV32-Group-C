-- ================================================================================
-- NEORV32 - IMEM-Boot Top (LED lamp test, Zicntr enabled, UART off, serial MUL)
-- ================================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_test_setup_bootloader is
  generic (
    CLOCK_FREQUENCY  : natural := 50000000;  -- Hz
    IMEM_SIZE        : natural := 16*1024;   -- bytes
    DMEM_SIZE        : natural := 8*1024;    -- bytes
    FAST_MUL_EN      : boolean := false;     -- serial multiplier for benchmarking
    LED_ACTIVE_LOW   : boolean := false;     -- flip if board LEDs are active-low
    POR_HOLD_CYCLES  : natural := 5_000_000; -- ~100ms @50MHz
    CHASER_CYCLES    : natural := 25_000_000;-- ~0.5s @50MHz
    HB_SHOW_CYCLES   : natural := 12_500_000 -- ~0.25s @50MHz
  );
  port (
    clk_i       : in  std_ulogic;
    rstn_i      : in  std_ulogic;
    gpio_o      : out std_ulogic_vector(7 downto 0);
    uart0_txd_o : out std_ulogic;
    uart0_rxd_i : in  std_ulogic
  );
end entity;

architecture rtl of neorv32_test_setup_bootloader is
  signal con_gpio_out : std_ulogic_vector(31 downto 0);
  signal por_cnt   : unsigned(31 downto 0) := (others => '0');
  signal por_done  : std_ulogic := '0';
  signal rstn_core : std_ulogic := '0';
  -- Lamp test
  signal lt_cnt  : unsigned(31 downto 0) := (others => '0');
  signal lt_done : std_ulogic := '0';
  signal lt_byte : std_ulogic_vector(7 downto 0) := (others => '0');
  -- Simple chaser
  signal po_cnt    : unsigned(31 downto 0) := (others => '0');
  signal po_show   : std_ulogic := '1';
  signal po_chaser : std_ulogic_vector(7 downto 0);
  -- Heartbeat window
  signal hb_cnt    : unsigned(31 downto 0) := (others => '0');
  signal hb_active : std_ulogic := '1';
  signal hb_byte   : std_ulogic_vector(7 downto 0);
  -- LED mux
  signal leds_cpu  : std_ulogic_vector(7 downto 0);
  signal leds_raw  : std_ulogic_vector(7 downto 0);
begin
  -- Reset stretcher
  process(clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      por_cnt  <= (others => '0');
      por_done <= '0';
    elsif rising_edge(clk_i) then
      if (por_done = '0') then
        if (por_cnt = to_unsigned(POR_HOLD_CYCLES, por_cnt'length)) then
          por_done <= '1';
        else
          por_cnt <= por_cnt + 1;
        end if;
      end if;
    end if;
  end process;
  rstn_core <= rstn_i and por_done;

  -- Lamp test: 0xFF -> 0x00 -> 0xAA -> 0x55
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if lt_done = '0' then
        lt_cnt <= lt_cnt + 1;
        if lt_cnt < to_unsigned(CLOCK_FREQUENCY/2*1, lt_cnt'length) then
          lt_byte <= x"FF";
        elsif lt_cnt < to_unsigned(CLOCK_FREQUENCY/2*2, lt_cnt'length) then
          lt_byte <= x"00";
        elsif lt_cnt < to_unsigned(CLOCK_FREQUENCY/2*3, lt_cnt'length) then
          lt_byte <= x"AA";
        elsif lt_cnt < to_unsigned(CLOCK_FREQUENCY/2*4, lt_cnt'length) then
          lt_byte <= x"55";
        else
          lt_done <= '1';
        end if;
      end if;
    end if;
  end process;

  -- Chaser window (~0.5s)
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (po_show = '1') then
        po_cnt <= po_cnt + 1;
        if po_cnt = to_unsigned(CHASER_CYCLES, po_cnt'length) then
          po_show <= '0';
        end if;
      end if;
    end if;
  end process;

  with std_logic_vector(po_cnt(13 downto 11)) select
    po_chaser <= "00000001" when "000",
                 "00000010" when "001",
                 "00000100" when "010",
                 "00001000" when "011",
                 "00010000" when "100",
                 "00100000" when "101",
                 "01000000" when "110",
                 "10000000" when others;

  -- NEORV32 SoC instance
  neorv32_top_inst: neorv32_top
    generic map (
      CLOCK_FREQUENCY  => CLOCK_FREQUENCY,
      BOOT_MODE_SELECT => 2,      -- IMEM image boot ('make install')
      RISCV_ISA_C      => true,
      RISCV_ISA_M      => true,   -- decode M; SW uses .insn to issue MUL
      RISCV_ISA_Zicntr => true,   -- expose cycle CSR for timing window
      IMEM_EN          => true,
      IMEM_SIZE        => IMEM_SIZE,
      DMEM_EN          => true,
      DMEM_SIZE        => DMEM_SIZE,
      IO_GPIO_NUM      => 8,
      IO_CLINT_EN      => true,
      IO_UART0_EN      => false,  -- UART fully off (LED-only)
      CPU_FAST_MUL_EN  => FAST_MUL_EN
    )
    port map (
      clk_i       => clk_i,
      rstn_i      => rstn_core,
      gpio_o      => con_gpio_out,
      uart0_txd_o => uart0_txd_o,
      uart0_rxd_i => uart0_rxd_i
    );

  -- Heartbeat while CPU starts
  process(clk_i, rstn_i)
  begin
    if (rstn_i = '0') then
      hb_cnt    <= (others => '0');
      hb_active <= '1';
    elsif rising_edge(clk_i) then
      if (hb_active = '1') then
        if (hb_cnt = to_unsigned(HB_SHOW_CYCLES, hb_cnt'length)) then
          hb_active <= '0';
        else
          hb_cnt <= hb_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  with hb_cnt(31 downto 29) select
    hb_byte <= x"AA" when "000",
               x"55" when "001",
               std_ulogic_vector(hb_cnt(15 downto 8)) when others;

  -- LED mux priority: lamp test > chaser > heartbeat > CPU
  leds_cpu <= con_gpio_out(7 downto 0);
  leds_raw <= lt_byte   when (lt_done = '0') else
              po_chaser when (po_show = '1') else
              hb_byte   when (hb_active = '1') else
              leds_cpu;

  gpio_o   <= (not leds_raw) when LED_ACTIVE_LOW else leds_raw;
end architecture;
