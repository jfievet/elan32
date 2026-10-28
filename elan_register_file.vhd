library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_register_file is
    generic (
        use_async_reset : boolean := true;
        use_sync_reset : boolean := true;
        async_reset_active : std_logic := '1';
        sync_reset_active : std_logic := '1' 
    );
    port (
        clock_i : in std_logic;
        async_reset_i : in std_logic;
        sync_reset_i : in std_logic;
        read_address_a_i : in std_logic_vector(4 downto 0);
        read_address_b_i : in std_logic_vector(4 downto 0);
        read_data_a_o : out std_logic_vector(31 downto 0);
        read_data_b_o : out std_logic_vector(31 downto 0);
        write_enable_i : in std_logic;
        write_address_i : in std_logic_vector(4 downto 0);
        write_data_i : in std_logic_vector(31 downto 0);
        debug_o : out std_logic_vector(1023 downto 0)
    );
end entity;

architecture rtl of elan_register_file is
    type registers_type is array (0 to 31) of std_logic_vector(31 downto 0);
    signal registers : registers_type;
begin
    read_data_a_o <= registers(to_integer(unsigned(read_address_a_i)));
    read_data_b_o <= registers(to_integer(unsigned(read_address_b_i)));
    debug_gen: for index in 0 to 31 generate
        debug_o(32 * index + 31 downto 32 * index) <= registers(index);
    end generate;
    state_pr: process (clock_i, async_reset_i) is
    begin
        if ((async_reset_i = async_reset_active) and (use_async_reset = true)) then
                registers <= (others => (others => '0'));
        elsif rising_edge(clock_i) then
            if ((sync_reset_i = sync_reset_active) and (use_sync_reset = true)) then
                registers <= (others => (others => '0'));
            else
                if write_enable_i = '1' and write_address_i /= "00000" then
                    registers(to_integer(unsigned(write_address_i))) <= write_data_i;
                end if;
            end if;
        end if;
    end process;

end architecture;
