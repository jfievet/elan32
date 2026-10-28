library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_multiplier is
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
        start_i : in std_logic;
        advance_i : in std_logic;
        a_i : in std_logic_vector(31 downto 0);
        b_i : in std_logic_vector(31 downto 0);
        operation_i : in std_logic_vector(1 downto 0);
        done_o : out std_logic;
        result_o : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of elan_multiplier is
    signal a_extended : signed(32 downto 0);
    signal b_extended : signed(32 downto 0);
    signal product : signed(65 downto 0);
    signal operation : std_logic_vector(1 downto 0);
    signal done : std_logic;
begin
    a_extended <= signed(a_i(31) & a_i) when operation_i = "01" or operation_i = "10" else signed('0' & a_i);
    b_extended <= signed(b_i(31) & b_i) when operation_i = "01" else signed('0' & b_i);
    done_o <= done;
    result_o <= std_logic_vector(product(31 downto 0)) when operation = "00" else std_logic_vector(product(63 downto 32));
    state_pr: process (clock_i, async_reset_i) is
    begin
        if ((async_reset_i = async_reset_active) and (use_async_reset = true)) then
                product <= (others => '0');
                operation <= "00";
                done <= '0';
        elsif rising_edge(clock_i) then
            if ((sync_reset_i = sync_reset_active) and (use_sync_reset = true)) then
                product <= (others => '0');
                operation <= "00";
                done <= '0';
            else
                if advance_i = '1' then
                    done <= '0';
                    if start_i = '1' then
                        product <= a_extended * b_extended;
                        operation <= operation_i;
                        done <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
