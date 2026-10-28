library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_core is
    generic (
        use_async_reset : boolean := true;
        use_sync_reset : boolean := true;
        async_reset_active : std_logic := '1';
        sync_reset_active : std_logic := '1' ;
        start_address : std_logic_vector(31 downto 0) := x"00000000";
        enable_multiplier : boolean := true;
        enable_divider : boolean := true
    );
    port (
        clock_i : in std_logic;
        async_reset_i : in std_logic;
        sync_reset_i : in std_logic;
        stall_i : in std_logic;
        fault_i : in std_logic;
        fault_o : out std_logic;
        registers_debug_o : out std_logic_vector(1023 downto 0);
        pc_debug_o : out std_logic_vector(31 downto 0);
        previous_pc_debug_o : out std_logic_vector(31 downto 0);
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

architecture rtl of elan_core is
    type stage_type is (if_start, if_wait, id_decode, ex_increment, ex_execute, ex_multiply, ex_divide, mem_start, mem_wait, mem_complete, wb_commit, halted);
    signal stage : stage_type;
    signal instruction : std_logic_vector(31 downto 0);
    signal opcode : std_logic_vector(6 downto 0);
    signal funct3 : std_logic_vector(2 downto 0);
    signal immediate : std_logic_vector(31 downto 0);
    signal decoded_operation : std_logic_vector(3 downto 0);
    signal legal : std_logic;
    signal a_value : std_logic_vector(31 downto 0);
    signal b_value : std_logic_vector(31 downto 0);
    -- Decode/read outputs terminate at the ID register boundary.
    signal raw_opcode : std_logic_vector(6 downto 0);
    signal raw_immediate : std_logic_vector(31 downto 0);
    signal raw_operation : std_logic_vector(3 downto 0);
    signal raw_legal : std_logic;
    signal raw_a_value, raw_b_value : std_logic_vector(31 downto 0);
    signal destination : std_logic_vector(4 downto 0);
    signal writes_register, is_register_alu, is_immediate_alu : std_logic;
    signal is_load, is_store, is_branch, is_jal, is_jalr : std_logic;
    signal is_lui, is_auipc, is_system : std_logic;
    signal branch_decision : std_logic;
    signal result : std_logic_vector(31 downto 0);
    signal sequential_pc : std_logic_vector(31 downto 0);
    signal next_pc : std_logic_vector(31 downto 0);
    signal pc : std_logic_vector(31 downto 0);
    signal commit : std_logic;
    signal write_register : std_logic;
    signal fault : std_logic;
    signal advance : std_logic;
    signal alu_a : std_logic_vector(31 downto 0);
    signal alu_b : std_logic_vector(31 downto 0);
    signal alu_operation : std_logic_vector(3 downto 0);
    signal alu_result : std_logic_vector(31 downto 0);
    signal equal_value : std_logic;
    signal signed_less : std_logic;
    signal unsigned_less : std_logic;
    signal branch_taken : std_logic;
    signal target : std_logic_vector(31 downto 0);
    signal is_m : std_logic;
    signal multiply_start : std_logic;
    signal divide_start : std_logic;
    signal multiply_done : std_logic;
    signal divide_done : std_logic;
    signal multiply_result : std_logic_vector(31 downto 0);
    signal divide_result : std_logic_vector(31 downto 0);
    signal request : std_logic;
    signal bus_write : std_logic;
    signal bus_instruction : std_logic;
    signal bus_address : std_logic_vector(31 downto 0);
    signal bus_data : std_logic_vector(31 downto 0);
    signal bus_strobe : std_logic_vector(3 downto 0);
    signal bus_ready : std_logic;
    signal bus_done : std_logic;
    signal bus_error : std_logic;
    signal bus_result : std_logic_vector(31 downto 0);
    signal consume : std_logic;
    signal memory_address : std_logic_vector(31 downto 0);
    signal shifted_load : std_logic_vector(31 downto 0);
    signal load_result : std_logic_vector(31 downto 0);
    signal access_misaligned : std_logic;

begin
    raw_opcode <= instruction(6 downto 0);
    fault_o <= fault;
    pc_debug_o <= pc;
    advance <= not stall_i and not fault and not fault_i;
    commit <= '1' when stage = wb_commit and advance = '1' else '0';
    write_register <= commit and writes_register;
    decoder_inst: entity work.elan_decoder port map (instruction, raw_immediate, raw_operation, raw_legal);
    registers_inst: entity work.elan_register_file
        generic map (use_async_reset, use_sync_reset, async_reset_active, sync_reset_active)
        port map (clock_i, async_reset_i, sync_reset_i, instruction(19 downto 15), instruction(24 downto 20), raw_a_value, raw_b_value, write_register, destination, result, registers_debug_o);
    pc_inst: entity work.elan_pc
        generic map (use_async_reset, use_sync_reset, async_reset_active, sync_reset_active, start_address)
        port map (clock_i, async_reset_i, sync_reset_i, commit, next_pc, pc, previous_pc_debug_o);
    comparator_inst: entity work.elan_comparator port map (a_value, b_value, equal_value, signed_less, unsigned_less);
    branch_decision <= equal_value when funct3 = "000" else not equal_value when funct3 = "001" else
                    signed_less when funct3 = "100" else not signed_less when funct3 = "101" else
                    unsigned_less when funct3 = "110" else not unsigned_less;
    alu_a <= pc when stage = ex_increment or is_jal = '1' or is_branch = '1' or is_auipc = '1' else a_value;
    alu_b <= x"00000004" when stage = ex_increment else b_value when is_register_alu = '1' else immediate;
    alu_operation <= decoded_operation when stage = ex_execute and (is_register_alu = '1' or is_immediate_alu = '1') else x"0";
    alu_inst: entity work.elan_alu port map (alu_a, alu_b, alu_operation, alu_result);
    target <= alu_result(31 downto 1) & '0' when is_jalr = '1' else alu_result;
    multiply_start <= '1' when stage = ex_execute and is_m = '1' and funct3(2) = '0' and advance = '1' else '0';
    divide_start <= '1' when stage = ex_execute and is_m = '1' and funct3(2) = '1' and advance = '1' else '0';
    multiplier_gen: if enable_multiplier generate
        multiplier_inst: entity work.elan_multiplier generic map (use_async_reset, use_sync_reset, async_reset_active, sync_reset_active)
            port map (clock_i, async_reset_i, sync_reset_i, multiply_start, advance, a_value, b_value, funct3(1 downto 0), multiply_done, multiply_result);
    end generate;
    no_multiplier_gen: if not enable_multiplier generate
        multiply_done <= '0';
        multiply_result <= (others => '0');
    end generate;
    divider_gen: if enable_divider generate
        divider_inst: entity work.elan_divider generic map (use_async_reset, use_sync_reset, async_reset_active, sync_reset_active)
            port map (clock_i, async_reset_i, sync_reset_i, divide_start, advance, a_value, b_value, funct3(0), funct3(1), divide_done, divide_result);
    end generate;
    no_divider_gen: if not enable_divider generate
        divide_done <= '0';
        divide_result <= (others => '0');
    end generate;
    bus_instruction <= '1' when stage = if_start else '0';
    bus_write <= '1' when stage = mem_start and is_store = '1' else '0';
    bus_address <= pc when stage = if_start else memory_address(31 downto 2) & "00";
    request <= '1' when advance = '1' and bus_ready = '1' and ((stage = if_start and pc(1 downto 0) = "00") or stage = mem_start) else '0';
    consume <= '1' when advance = '1' and bus_done = '1' and (stage = if_wait or stage = mem_wait) else '0';
    bus_data <= std_logic_vector(shift_left(unsigned(b_value), 8 * to_integer(unsigned(memory_address(1 downto 0)))));
    bus_strobe <= std_logic_vector(shift_left(to_unsigned(1, 4), to_integer(unsigned(memory_address(1 downto 0))))) when funct3 = "000" else
                    std_logic_vector(shift_left(to_unsigned(3, 4), to_integer(unsigned(memory_address(1 downto 0))))) when funct3 = "001" else "1111";
    shifted_load <= std_logic_vector(shift_right(unsigned(bus_result), 8 * to_integer(unsigned(memory_address(1 downto 0)))));
    load_result <= std_logic_vector(resize(signed(shifted_load(7 downto 0)), 32)) when funct3 = "000" else
                    std_logic_vector(resize(signed(shifted_load(15 downto 0)), 32)) when funct3 = "001" else
                    x"000000" & shifted_load(7 downto 0) when funct3 = "100" else
                    x"0000" & shifted_load(15 downto 0) when funct3 = "101" else bus_result;
    access_misaligned <= '1' when (funct3(1 downto 0) = "01" and alu_result(0) = '1') or (funct3 = "010" and alu_result(1 downto 0) /= "00") else '0';
    bus_inst: entity work.elan_axi_master generic map (use_async_reset, use_sync_reset, async_reset_active, sync_reset_active)
        port map (clock_i, async_reset_i, sync_reset_i, request, bus_write, bus_instruction, bus_address, bus_data, bus_strobe, consume, bus_ready, bus_done, bus_result, bus_error,
            m_axi_awaddr_o,
            m_axi_awprot_o,
            m_axi_awvalid_o,
            m_axi_awready_i,
            m_axi_wdata_o,
            m_axi_wstrb_o,
            m_axi_wvalid_o,
            m_axi_wready_i,
            m_axi_bresp_i,
            m_axi_bvalid_i,
            m_axi_bready_o,
            m_axi_araddr_o,
            m_axi_arprot_o,
            m_axi_arvalid_o,
            m_axi_arready_i,
            m_axi_rdata_i,
            m_axi_rresp_i,
            m_axi_rvalid_i,
            m_axi_rready_o);

    state_pr: process (clock_i, async_reset_i) is
    begin
        if ((async_reset_i = async_reset_active) and (use_async_reset = true)) then
                stage <= if_start;
                instruction <= (others => '0');
                opcode <= (others => '0');
                funct3 <= (others => '0');
                immediate <= (others => '0');
                decoded_operation <= (others => '0');
                legal <= '0';
                destination <= (others => '0');
                a_value <= (others => '0');
                b_value <= (others => '0');
                writes_register <= '0';
                is_register_alu <= '0';
                is_immediate_alu <= '0';
                is_load <= '0';
                is_store <= '0';
                is_branch <= '0';
                is_jal <= '0';
                is_jalr <= '0';
                is_lui <= '0';
                is_auipc <= '0';
                is_system <= '0';
                is_m <= '0';
                branch_taken <= '0';
                result <= (others => '0');
                sequential_pc <= start_address;
                next_pc <= start_address;
                memory_address <= (others => '0');
                fault <= '0';
        elsif rising_edge(clock_i) then
            if ((sync_reset_i = sync_reset_active) and (use_sync_reset = true)) then
                stage <= if_start;
                instruction <= (others => '0');
                opcode <= (others => '0');
                funct3 <= (others => '0');
                immediate <= (others => '0');
                decoded_operation <= (others => '0');
                legal <= '0';
                destination <= (others => '0');
                a_value <= (others => '0');
                b_value <= (others => '0');
                writes_register <= '0';
                is_register_alu <= '0';
                is_immediate_alu <= '0';
                is_load <= '0';
                is_store <= '0';
                is_branch <= '0';
                is_jal <= '0';
                is_jalr <= '0';
                is_lui <= '0';
                is_auipc <= '0';
                is_system <= '0';
                is_m <= '0';
                branch_taken <= '0';
                result <= (others => '0');
                sequential_pc <= start_address;
                next_pc <= start_address;
                memory_address <= (others => '0');
                fault <= '0';
            else
                if fault_i = '1' or (bus_done = '1' and bus_error = '1') then
                    fault <= '1';
                    stage <= halted;
                elsif advance = '1' then
                    -- IF: only one instruction can be active.
                    if stage = if_start then
                        if pc(1 downto 0) /= "00" then
                            fault <= '1';
                            stage <= halted;
                        elsif request = '1' then
                            stage <= if_wait;
                        end if;
                    elsif stage = if_wait then
                        if bus_done = '1' then
                            instruction <= bus_result;
                            stage <= id_decode;
                        end if;
                    -- ID: capture operands and controls before execution.
                    elsif stage = id_decode then
                        opcode <= raw_opcode;
                        funct3 <= instruction(14 downto 12);
                        immediate <= raw_immediate;
                        decoded_operation <= raw_operation;
                        legal <= raw_legal;
                        destination <= instruction(11 downto 7);
                        a_value <= raw_a_value;
                        b_value <= raw_b_value;
                        writes_register <= '0';
                        if raw_opcode = "0110011" or raw_opcode = "0010011" or raw_opcode = "0000011" or
                           raw_opcode = "0110111" or raw_opcode = "0010111" or raw_opcode = "1101111" or raw_opcode = "1100111" then
                            writes_register <= '1';
                        end if;
                        is_register_alu <= '0';
                        if raw_opcode = "0110011" then is_register_alu <= '1'; end if;
                        is_immediate_alu <= '0';
                        if raw_opcode = "0010011" then is_immediate_alu <= '1'; end if;
                        is_load <= '0';
                        if raw_opcode = "0000011" then is_load <= '1'; end if;
                        is_store <= '0';
                        if raw_opcode = "0100011" then is_store <= '1'; end if;
                        is_branch <= '0';
                        if raw_opcode = "1100011" then is_branch <= '1'; end if;
                        is_jal <= '0';
                        if raw_opcode = "1101111" then is_jal <= '1'; end if;
                        is_jalr <= '0';
                        if raw_opcode = "1100111" then is_jalr <= '1'; end if;
                        is_lui <= '0';
                        if raw_opcode = "0110111" then is_lui <= '1'; end if;
                        is_auipc <= '0';
                        if raw_opcode = "0010111" then is_auipc <= '1'; end if;
                        is_system <= '0';
                        if raw_opcode = "1110011" then is_system <= '1'; end if;
                        is_m <= '0';
                        if raw_opcode = "0110011" and instruction(31 downto 25) = "0000001" then
                            is_m <= '1';
                        end if;
                        stage <= ex_increment;
                    -- Reject invalid instructions before side effects; share the ALU for PC+4.
                    elsif stage = ex_increment then
                        if legal = '0' or is_system = '1' or
                            (is_m = '1' and funct3(2) = '0' and not enable_multiplier) or
                            (is_m = '1' and funct3(2) = '1' and not enable_divider) then
                            fault <= '1';
                            stage <= halted;
                        else
                            sequential_pc <= alu_result;
                            next_pc <= alu_result;
                            branch_taken <= branch_decision;
                            stage <= ex_execute;
                        end if;
                    elsif stage = ex_execute then
                        stage <= mem_complete;
                        if is_m = '1' then
                            if funct3(2) = '0' then
                                stage <= ex_multiply;
                            else
                                stage <= ex_divide;
                            end if;
                        elsif is_load = '1' or is_store = '1' then
                            memory_address <= alu_result;
                            if access_misaligned = '1' then
                                fault <= '1';
                                stage <= halted;
                            else
                                stage <= mem_start;
                            end if;
                        elsif is_jal = '1' or is_jalr = '1' or (is_branch = '1' and branch_taken = '1') then
                            if target(1 downto 0) /= "00" then
                                fault <= '1';
                                stage <= halted;
                            else
                                next_pc <= target;
                                result <= sequential_pc;
                            end if;
                        elsif is_lui = '1' then
                            result <= immediate;
                        else
                            result <= alu_result;
                        end if;
                    elsif stage = ex_multiply then
                        if multiply_done = '1' then
                            result <= multiply_result;
                            stage <= mem_complete;
                        end if;
                    elsif stage = ex_divide then
                        if divide_done = '1' then
                            result <= divide_result;
                            stage <= mem_complete;
                        end if;
                    -- MEM: bus engine continues independently during stall/fault.
                    elsif stage = mem_start then
                        if request = '1' then
                            stage <= mem_wait;
                        end if;
                    elsif stage = mem_wait then
                        if bus_done = '1' then
                            result <= load_result;
                            stage <= mem_complete;
                        end if;
                    elsif stage = mem_complete then
                        stage <= wb_commit;
                    -- WB: atomic architectural register/PC retirement.
                    elsif stage = wb_commit then
                        stage <= if_start;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
