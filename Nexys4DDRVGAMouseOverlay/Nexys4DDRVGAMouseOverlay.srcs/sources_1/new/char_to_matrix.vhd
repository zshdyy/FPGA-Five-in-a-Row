library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity char_to_matrix is
    Port (
        ascii_in : in STD_LOGIC_VECTOR(7 downto 0); -- 输入ASCII码
        addr_row : in STD_LOGIC_VECTOR(2 downto 0); -- 行地址（0-7）
        addr_col : in STD_LOGIC_VECTOR(2 downto 0); -- 列地址（0-7）
        data_out : out STD_LOGIC                    -- 输出点状态（1或0）
    );
end char_to_matrix;

architecture Behavioral of char_to_matrix is
    type row_type is array (0 to 7) of STD_LOGIC;
    type matrix_type is array (0 to 7) of row_type;
    type char_map_type is array (0 to 127) of matrix_type; -- 支持ASCII码0到127
    
    -- 定义一些常见字符的8x8点阵数据
    constant char_map : char_map_type := (
        32 => ("00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000"), -- Space
        65 => ("00010000", "00110000", "01010000", "01110000", "01010000", "01010000", "01010000", "01010000"), -- A
        66 => ("11100000", "11100000", "11010000", "11010000", "11100000", "11100000", "11010000", "11010000"), -- B
        67 => ("01110000", "11000000", "10000000", "10000000", "10000000", "10000000", "11000000", "01110000"), -- C
        68 => ("11100000", "11010000", "11010000", "11010000", "11010000", "11010000", "11010000", "11100000"), -- D
        69 => ("11110000", "11000000", "11000000", "11110000", "11000000", "11000000", "11000000", "11110000"), -- E
        70 => ("11110000", "11000000", "11000000", "11110000", "11000000", "11000000", "11000000", "11000000"), -- F
        71 => ("01110000", "11000000", "10000000", "10000000", "10110000", "11010000", "11010000", "01110000"), -- G
        82 => ("11100000", "11100000", "11010000", "11010000", "11100000", "11010000", "11010000", "11010000"), -- R
        83 => ("01110000", "11000000", "11000000", "01110000", "00010000", "00010000", "11000000", "01110000"), -- S
        84 => ("11110000", "00100000", "00100000", "00100000", "00100000", "00100000", "00100000", "00100000"), -- T
        others => ("00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000") -- Default (Space)
    );

begin
    process(ascii_in, addr_row, addr_col)
    begin
        if to_integer(unsigned(ascii_in)) < 128  then
            data_out <= char_map(to_integer(unsigned(ascii_in)))(to_integer(unsigned(addr_row)))(to_integer(unsigned(addr_col)));
        else
            data_out <= '0'; -- 默认为空格
        end if;
    end process;
end Behavioral;



