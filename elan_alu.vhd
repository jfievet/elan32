library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_alu is
    port (
        a_i : in std_logic_vector(31 downto 0);
        b_i : in std_logic_vector(31 downto 0);
        operation_i : in std_logic_vector(3 downto 0);
        result_o : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of elan_alu is
    signal shifted : std_logic_vector(31 downto 0);
    signal equal_value : std_logic;
    signal signed_less : std_logic;
    signal unsigned_less : std_logic;
    signal shift_right_value : std_logic;
    signal shift_arithmetic : std_logic;
begin
    -- Operations: add, sub, xor, or, and, sll, srl, sra, slt, sltu.
    shift_right_value <= '0' when operation_i = x"5" else '1';
    shift_arithmetic <= '1' when operation_i = x"7" else '0';
    shifter_inst: entity work.elan_shifter port map (a_i, b_i(4 downto 0), shift_right_value, shift_arithmetic, shifted);
    comparator_inst: entity work.elan_comparator port map (a_i, b_i, equal_value, signed_less, unsigned_less);
    result_o <= std_logic_vector(unsigned(a_i) + unsigned(b_i)) when operation_i = x"0" else
                std_logic_vector(unsigned(a_i) - unsigned(b_i)) when operation_i = x"1" else
                a_i xor b_i when operation_i = x"2" else
                a_i or b_i when operation_i = x"3" else
                a_i and b_i when operation_i = x"4" else
                shifted when operation_i = x"5" or operation_i = x"6" or operation_i = x"7" else
                "0000000000000000000000000000000" & signed_less when operation_i = x"8" else
                "0000000000000000000000000000000" & unsigned_less;
end architecture;
