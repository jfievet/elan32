library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_divider is
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
        unsigned_i : in std_logic;
        remainder_i : in std_logic;
        done_o : out std_logic;
        result_o : out std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of elan_divider is
    signal quotient : unsigned(31 downto 0);
    signal remainder_value : unsigned(32 downto 0);
    signal divisor : unsigned(31 downto 0);
    signal trial : unsigned(32 downto 0);
    signal reduced : unsigned(32 downto 0);
    signal next_quotient : unsigned(31 downto 0);
    signal count : unsigned(5 downto 0);
    signal busy : std_logic;
    signal done : std_logic;
    signal negate_quotient : std_logic;
    signal negate_remainder : std_logic;
    signal select_remainder : std_logic;
    signal result : std_logic_vector(31 downto 0);
    signal magnitude_a : unsigned(31 downto 0);
    signal magnitude_b : unsigned(31 downto 0);
begin
    magnitude_a <= unsigned(-signed(a_i)) when unsigned_i = '0' and a_i(31) = '1' else unsigned(a_i);
    magnitude_b <= unsigned(-signed(b_i)) when unsigned_i = '0' and b_i(31) = '1' else unsigned(b_i);
    trial <= remainder_value(31 downto 0) & quotient(31);
    reduced <= trial - ('0' & divisor) when trial >= ('0' & divisor) else trial;
    next_quotient <= quotient(30 downto 0) & '1' when trial >= ('0' & divisor) else quotient(30 downto 0) & '0';
    result_o <= result;
    done_o <= done;
    state_pr: process (clock_i, async_reset_i) is
    begin
        if ((async_reset_i = async_reset_active) and (use_async_reset = true)) then
                quotient <= (others => '0');
                remainder_value <= (others => '0');
                divisor <= (others => '0');
                count <= (others => '0');
                busy <= '0';
                done <= '0';
                negate_quotient <= '0';
                negate_remainder <= '0';
                select_remainder <= '0';
                result <= (others => '0');
        elsif rising_edge(clock_i) then
            if ((sync_reset_i = sync_reset_active) and (use_sync_reset = true)) then
                quotient <= (others => '0');
                remainder_value <= (others => '0');
                divisor <= (others => '0');
                count <= (others => '0');
                busy <= '0';
                done <= '0';
                negate_quotient <= '0';
                negate_remainder <= '0';
                select_remainder <= '0';
                result <= (others => '0');
            else
                if advance_i = '1' then
                    done <= '0';
                    if start_i = '1' and busy = '0' then
                        if b_i = x"00000000" then
                            if remainder_i = '1' then
                                result <= a_i;
                            else
                                result <= x"ffffffff";
                            end if;
                            done <= '1';
                        elsif unsigned_i = '0' and a_i = x"80000000" and b_i = x"ffffffff" then
                            if remainder_i = '1' then
                                result <= x"00000000";
                            else
                                result <= x"80000000";
                            end if;
                            done <= '1';
                        else
                            quotient <= magnitude_a;
                            divisor <= magnitude_b;
                            remainder_value <= (others => '0');
                            negate_quotient <= (a_i(31) xor b_i(31)) and not unsigned_i;
                            negate_remainder <= a_i(31) and not unsigned_i;
                            select_remainder <= remainder_i;
                            count <= (others => '0');
                            busy <= '1';
                        end if;
                    elsif busy = '1' then
                        quotient <= next_quotient;
                        remainder_value <= reduced;
                        count <= count + 1;
                        if count = 31 then
                            busy <= '0';
                            done <= '1';
                            if select_remainder = '1' then
                                if negate_remainder = '1' then
                                    result <= std_logic_vector(-signed(reduced(31 downto 0)));
                                else
                                    result <= std_logic_vector(reduced(31 downto 0));
                                end if;
                            else
                                if negate_quotient = '1' then
                                    result <= std_logic_vector(-signed(next_quotient));
                                else
                                    result <= std_logic_vector(next_quotient);
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
