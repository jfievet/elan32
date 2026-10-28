library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_pc is
    generic (
        use_async_reset : boolean := true;
        use_sync_reset : boolean := true;
        async_reset_active : std_logic := '1';
        sync_reset_active : std_logic := '1' ;
        start_address : std_logic_vector(31 downto 0) := x"00000000"
    );
    port (
        clock_i : in std_logic;
        async_reset_i : in std_logic;
        sync_reset_i : in std_logic;
        commit_i : in std_logic;
        next_pc_i : in std_logic_vector(31 downto 0);
        pc_o : out std_logic_vector(31 downto 0);
        previous_pc_o : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of elan_pc is
    signal pc : std_logic_vector(31 downto 0);
    signal previous_pc : std_logic_vector(31 downto 0);
begin
    pc_o <= pc;
    previous_pc_o <= previous_pc;
    state_pr: process (clock_i, async_reset_i) is
    begin
        if ((async_reset_i = async_reset_active) and (use_async_reset = true)) then
                pc <= start_address;
                previous_pc <= start_address;
        elsif rising_edge(clock_i) then
            if ((sync_reset_i = sync_reset_active) and (use_sync_reset = true)) then
                pc <= start_address;
                previous_pc <= start_address;
            else
                if commit_i = '1' then
                    previous_pc <= pc;
                    pc <= next_pc_i;
                end if;
            end if;
        end if;
    end process;

end architecture;
