library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elan_decoder is
    port (
        instruction_i : in std_logic_vector(31 downto 0);
        immediate_o : out std_logic_vector(31 downto 0);
        alu_operation_o : out std_logic_vector(3 downto 0);
        legal_o : out std_logic
    );
end entity;

architecture rtl of elan_decoder is
    signal opcode : std_logic_vector(6 downto 0);
    signal funct3 : std_logic_vector(2 downto 0);
    signal funct7 : std_logic_vector(6 downto 0);
    signal base_register_legal : boolean;
    signal immediate_legal : boolean;
begin
    opcode <= instruction_i(6 downto 0);
    funct3 <= instruction_i(14 downto 12);
    funct7 <= instruction_i(31 downto 25);
    immediate_o <= std_logic_vector(resize(signed(instruction_i(31 downto 20)), 32)) when opcode = "0010011" or opcode = "0000011" or opcode = "1100111" else
                    std_logic_vector(resize(signed(instruction_i(31 downto 25) & instruction_i(11 downto 7)), 32)) when opcode = "0100011" else
                    std_logic_vector(resize(signed(instruction_i(31) & instruction_i(7) & instruction_i(30 downto 25) & instruction_i(11 downto 8) & '0'), 32)) when opcode = "1100011" else
                    std_logic_vector(resize(signed(instruction_i(31) & instruction_i(19 downto 12) & instruction_i(20) & instruction_i(30 downto 21) & '0'), 32)) when opcode = "1101111" else
                    instruction_i(31 downto 12) & x"000";
    base_register_legal <= funct7 = "0000000" or (funct7 = "0100000" and (funct3 = "000" or funct3 = "101"));
    immediate_legal <= (funct3 /= "001" and funct3 /= "101") or
                        (funct3 = "001" and funct7 = "0000000") or
                        (funct3 = "101" and (funct7 = "0000000" or funct7 = "0100000"));
    legal_o <= '1' when
        (opcode = "0110011" and (base_register_legal or funct7 = "0000001")) or
        (opcode = "0010011" and immediate_legal) or
        (opcode = "0000011" and (funct3 = "000" or funct3 = "001" or funct3 = "010" or funct3 = "100" or funct3 = "101")) or
        (opcode = "0100011" and (funct3 = "000" or funct3 = "001" or funct3 = "010")) or
        (opcode = "1100011" and (funct3 = "000" or funct3 = "001" or funct3 = "100" or funct3 = "101" or funct3 = "110" or funct3 = "111")) or
        (opcode = "1100111" and funct3 = "000") or opcode = "1101111" or opcode = "0110111" or opcode = "0010111" or
        (opcode = "0001111" and funct3 = "000") or instruction_i = x"00000073" or instruction_i = x"00100073"
        else '0';
    alu_operation_o <= x"1" when opcode = "0110011" and funct3 = "000" and funct7 = "0100000" else
                        x"2" when funct3 = "100" else
                        x"3" when funct3 = "110" else
                        x"4" when funct3 = "111" else
                        x"5" when funct3 = "001" else
                        x"7" when funct3 = "101" and funct7 = "0100000" else
                        x"6" when funct3 = "101" else
                        x"8" when funct3 = "010" else
                        x"9" when funct3 = "011" else x"0";
end architecture;
