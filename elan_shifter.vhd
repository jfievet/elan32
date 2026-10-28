library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_shifter is
    port (
        operand_i : in std_logic_vector(31 downto 0);
        amount_i : in std_logic_vector(4 downto 0);
        right_i : in std_logic;
        arithmetic_i : in std_logic;
        result_o : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of elan_shifter is

begin
    result_o <= std_logic_vector(shift_left(unsigned(operand_i), to_integer(unsigned(amount_i)))) when right_i = '0' else
                std_logic_vector(shift_right(signed(operand_i), to_integer(unsigned(amount_i)))) when arithmetic_i = '1' else
                std_logic_vector(shift_right(unsigned(operand_i), to_integer(unsigned(amount_i))));
end architecture;
