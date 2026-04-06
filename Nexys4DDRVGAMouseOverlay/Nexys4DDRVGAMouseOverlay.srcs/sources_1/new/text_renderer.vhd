library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity text_renderer is
    Port (
        clk         : in  STD_LOGIC;
        hcount      : in  STD_LOGIC_VECTOR(11 downto 0); -- VGA水平计数器
        vcount      : in  STD_LOGIC_VECTOR(11 downto 0); -- VGA垂直计数器
        x_start     : in  integer; -- 字符起始X坐标
        y_start     : in  integer; -- 字符起始Y坐标
        char_active : out STD_LOGIC
    );
end text_renderer;

architecture Behavioral of text_renderer is
    -- 字符参数
    constant CHAR_WIDTH  : integer := 32;   -- 字符宽度（像素）
    constant CHAR_HEIGHT : integer := 32;   -- 字符高度（像素）
    
    signal char_index : integer range 0 to 4 := 0;    
    -- 地址计算
    signal row, col : integer;
    signal row_tmp, col_tmp: std_logic_vector(2 downto 0);
    signal data: std_logic;
    signal judge: std_logic;
    signal x_pos      : integer := 0;
    signal str_addr: std_logic_vector(7 downto 0);

begin
   
    -- 计算字符位置
    process(clk)
    begin
        if rising_edge(clk) then
            -- 计算字符索引
            char_index <= (TO_INTEGER(unsigned(hcount)) - x_start) / CHAR_WIDTH;
            if char_index < 0 then
                char_index <= 0;
            elsif char_index > 4 then
                char_index <= 4;
            end if;
            
            -- 计算当前字符的起始X坐标
            x_pos <= x_start + char_index * CHAR_WIDTH;
            
            -- 转换坐标为整数
            row <= TO_INTEGER(unsigned(vcount)) - y_start;
            col <= TO_INTEGER(unsigned(hcount)) - x_pos;
            
            -- 生成ROM地址
            if (row >= 0) and (row < CHAR_HEIGHT) and 
               (col >= 0) and (col < CHAR_WIDTH) then
                judge <= '1';
                row_tmp <= std_logic_vector(TO_UNSIGNED(row / 4, 3));
                col_tmp <= std_logic_vector(TO_UNSIGNED(col / 4, 3));
            else
                judge <= '0';
            end if;
        end if;
    end process;
    
    -- 字符地址映射
    process(char_index)
    begin
        case char_index is
            when 0 => str_addr <= "01010010"; -- 'R'
            when 1 => str_addr <= "01000101"; -- 'E'
            when 2 => str_addr <= "01010011"; -- 'S'
            when 3 => str_addr <= "01000101"; -- 'E'
            when 4 => str_addr <= "01010100"; -- 'T'
            when others => str_addr <= "00000000"; -- 空格
        end case;
    end process;
   
    -- 读取字符数据
    char_rom_inst: entity work.char_to_matrix
    port map (
        ascii_in => str_addr,
        addr_row => row_tmp, 
        addr_col => col_tmp,
        data_out => data
    );

    char_active <= judge and data;
    
end Behavioral;
