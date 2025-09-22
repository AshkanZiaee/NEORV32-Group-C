library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_cpu_cp_muldiv is
  generic (
    FAST_MUL_EN : boolean := false;
    DIVISION_EN : boolean := false
  );
  port (
    clk_i   : in  std_ulogic;
    rstn_i  : in  std_ulogic;
    ctrl_i  : in  ctrl_bus_t;
    rs1_i   : in  std_ulogic_vector(XLEN-1 downto 0);
    rs2_i   : in  std_ulogic_vector(XLEN-1 downto 0);
    res_o   : out std_ulogic_vector(XLEN-1 downto 0);
    valid_o : out std_ulogic
  );
end neorv32_cpu_cp_muldiv;

architecture rtl of neorv32_cpu_cp_muldiv is
begin
  u_r4: entity neorv32.neorv32_cpu_cp_muldiv_r4booth
    port map (
      clk_i   => clk_i,
      rstn_i  => rstn_i,
      ctrl_i  => ctrl_i,
      rs1_i   => rs1_i,
      rs2_i   => rs2_i,
      res_o   => res_o,
      valid_o => valid_o
    );
end rtl;
