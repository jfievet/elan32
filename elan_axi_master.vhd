library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_axi_master is
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
        request_i : in std_logic;
        write_i : in std_logic;
        instruction_i : in std_logic;
        address_i : in std_logic_vector(31 downto 0);
        data_i : in std_logic_vector(31 downto 0);
        strobe_i : in std_logic_vector(3 downto 0);
        consume_i : in std_logic;
        ready_o : out std_logic;
        done_o : out std_logic;
        data_o : out std_logic_vector(31 downto 0);
        error_o : out std_logic;
        m_axi_awaddr_o : out std_logic_vector(31 downto 0);
        m_axi_awprot_o : out std_logic_vector(2 downto 0);
        m_axi_awvalid_o : out std_logic;
        m_axi_awready_i : in std_logic;
        m_axi_wdata_o : out std_logic_vector(31 downto 0);
        m_axi_wstrb_o : out std_logic_vector(3 downto 0);
        m_axi_wvalid_o : out std_logic;
        m_axi_wready_i : in std_logic;
        m_axi_bresp_i : in std_logic_vector(1 downto 0);
        m_axi_bvalid_i : in std_logic;
        m_axi_bready_o : out std_logic;
        m_axi_araddr_o : out std_logic_vector(31 downto 0);
        m_axi_arprot_o : out std_logic_vector(2 downto 0);
        m_axi_arvalid_o : out std_logic;
        m_axi_arready_i : in std_logic;
        m_axi_rdata_i : in std_logic_vector(31 downto 0);
        m_axi_rresp_i : in std_logic_vector(1 downto 0);
        m_axi_rvalid_i : in std_logic;
        m_axi_rready_o : out std_logic
    );
end entity;

architecture rtl of elan_axi_master is
    signal m_axi_rready : std_logic;
    signal m_axi_bready : std_logic;
    signal busy : std_logic;
    signal done : std_logic;
    signal writing : std_logic;
    signal aw_pending : std_logic;
    signal w_pending : std_logic;
    signal ar_pending : std_logic;
    signal address : std_logic_vector(31 downto 0);
    signal write_data : std_logic_vector(31 downto 0);
    signal strobe : std_logic_vector(3 downto 0);
    signal protection : std_logic_vector(2 downto 0);
    signal read_data : std_logic_vector(31 downto 0);
    signal error_value : std_logic;
begin
    ready_o <= not busy and not done;
    done_o <= done;
    data_o <= read_data;
    error_o <= error_value;
    m_axi_awaddr_o <= address;
    m_axi_araddr_o <= address;
    m_axi_awprot_o <= protection;
    m_axi_arprot_o <= protection;
    m_axi_wdata_o <= write_data;
    m_axi_wstrb_o <= strobe;
    m_axi_awvalid_o <= aw_pending;
    m_axi_wvalid_o <= w_pending;
    m_axi_arvalid_o <= ar_pending;
    m_axi_bready_o <= m_axi_bready;
    m_axi_bready <= busy and writing and not aw_pending and not w_pending;
    m_axi_rready_o <= m_axi_rready;
    m_axi_rready <= busy and not writing and not ar_pending;
    state_pr: process (clock_i, async_reset_i) is
    begin
        if ((async_reset_i = async_reset_active) and (use_async_reset = true)) then
                busy <= '0';
                done <= '0';
                writing <= '0';
                aw_pending <= '0';
                w_pending <= '0';
                ar_pending <= '0';
                address <= (others => '0');
                write_data <= (others => '0');
                strobe <= (others => '0');
                protection <= (others => '0');
                read_data <= (others => '0');
                error_value <= '0';
        elsif rising_edge(clock_i) then
            if ((sync_reset_i = sync_reset_active) and (use_sync_reset = true)) then
                busy <= '0';
                done <= '0';
                writing <= '0';
                aw_pending <= '0';
                w_pending <= '0';
                ar_pending <= '0';
                address <= (others => '0');
                write_data <= (others => '0');
                strobe <= (others => '0');
                protection <= (others => '0');
                read_data <= (others => '0');
                error_value <= '0';
            else
                if consume_i = '1' then
                    done <= '0';
                end if;
                if request_i = '1' and busy = '0' and done = '0' then
                    busy <= '1';
                    writing <= write_i;
                    address <= address_i;
                    write_data <= data_i;
                    strobe <= strobe_i;
                    protection <= instruction_i & "00";
                    error_value <= '0';
                    aw_pending <= write_i;
                    w_pending <= write_i;
                    ar_pending <= not write_i;
                end if;
                if aw_pending = '1' and m_axi_awready_i = '1' then
                    aw_pending <= '0';
                end if;
                if w_pending = '1' and m_axi_wready_i = '1' then
                    w_pending <= '0';
                end if;
                if ar_pending = '1' and m_axi_arready_i = '1' then
                    ar_pending <= '0';
                end if;
                if m_axi_bready = '1' and m_axi_bvalid_i = '1' then
                    busy <= '0';
                    done <= '1';
                    if m_axi_bresp_i /= "00" then
                        error_value <= '1';
                    end if;
                end if;
                if m_axi_rready = '1' and m_axi_rvalid_i = '1' then
                    busy <= '0';
                    done <= '1';
                    read_data <= m_axi_rdata_i;
                    if m_axi_rresp_i /= "00" then
                        error_value <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
