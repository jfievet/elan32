library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_comparator is
    port (
        a_i : in std_logic_vector(31 downto 0);
        b_i : in std_logic_vector(31 downto 0);
        equal_o : out std_logic;
        signed_less_o : out std_logic;
        unsigned_less_o : out std_logic
    );
end entity;

architecture rtl of elan_comparator is

begin
    equal_o <= '1' when a_i = b_i else '0';
    signed_less_o <= '1' when signed(a_i) < signed(b_i) else '0';
    unsigned_less_o <= '1' when unsigned(a_i) < unsigned(b_i) else '0';
end architecture;
