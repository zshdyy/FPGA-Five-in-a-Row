library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity piece_render is
    Port (
        clk         : in  STD_LOGIC;
        hcount      : in  STD_LOGIC_VECTOR(11 downto 0);
        vcount      : in  STD_LOGIC_VECTOR(11 downto 0);
        board_state : in  STD_LOGIC_VECTOR(49 downto 0);
        current_player : in STD_LOGIC;
        last_move_x : in INTEGER range 0 to 4;
        last_move_y : in INTEGER range 0 to 4;
        -- 输出颜色
        piece_red   : out STD_LOGIC_VECTOR(3 downto 0);
        piece_green : out STD_LOGIC_VECTOR(3 downto 0);
        piece_blue  : out STD_LOGIC_VECTOR(3 downto 0);
        piece_active : out STD_LOGIC
    );
end piece_render;

architecture Behavioral of piece_render is
    constant GRID_SIZE     : integer := 5;    -- 5x5棋盘
    constant CELL_SIZE     : integer := 100;  -- 每个单元格100像素
    constant LINE_WIDTH    : integer := 2;    -- 网格线宽度2像素
    constant BOARD_WIDTH   : integer := GRID_SIZE*(CELL_SIZE + LINE_WIDTH) - LINE_WIDTH;
    constant BOARD_HEIGHT  : integer := BOARD_WIDTH;
    constant FRAME_WIDTH : natural := 1920;
    constant FRAME_HEIGHT : natural := 1080;


    constant PIECE_RADIUS : integer := 30;
    constant BOARD_OFFSET_X : integer := (FRAME_WIDTH - BOARD_WIDTH)/2;
    constant BOARD_OFFSET_Y : integer := (FRAME_HEIGHT - BOARD_WIDTH)/2;

    
    -- 新增颜色常量
    constant COLOR_BLACK : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant COLOR_WHITE : STD_LOGIC_VECTOR(3 downto 0) := "1111";
    constant COLOR_HIGHLIGHT : STD_LOGIC_VECTOR(3 downto 0) := "0010";  -- 高亮
    
    signal piece_x, piece_y : integer;
begin
    process(hcount, vcount)
        variable x_pos, y_pos : integer;
        variable dist_sq : integer;
        variable cell_x, cell_y : integer;
        variable cell_state : STD_LOGIC_VECTOR(1 downto 0);
        variable is_last_move : STD_LOGIC;
    begin
        -- 初始化默认值
        piece_active <= '0';
        piece_red <= (others => '0');
        piece_green <= (others => '0');
        piece_blue <= (others => '0');
        x_pos := to_integer(unsigned(hcount));
        y_pos := to_integer(unsigned(vcount));
        -- 修改边界检查为条件执行块
        if x_pos >= BOARD_OFFSET_X and x_pos < BOARD_OFFSET_X + 5*CELL_SIZE and
           y_pos >= BOARD_OFFSET_Y and y_pos < BOARD_OFFSET_Y + 5*CELL_SIZE then
            
            -- 精确计算格子位置
            cell_x := (x_pos - BOARD_OFFSET_X) / CELL_SIZE;
            cell_y := (y_pos - BOARD_OFFSET_Y) / CELL_SIZE;
            
            -- 获取格子状态（2bit）
            cell_state := board_state((cell_y*5 + cell_x)*2 + 1 downto (cell_y*5 + cell_x)*2);
            
            -- 仅在有棋子时渲染
            if cell_state /= "00" then
                -- 计算中心坐标
                piece_x <= BOARD_OFFSET_X + cell_x*CELL_SIZE + CELL_SIZE/2;
                piece_y <= BOARD_OFFSET_Y + cell_y*CELL_SIZE + CELL_SIZE/2;
                
                -- 距离计算
                dist_sq := (x_pos - piece_x)**2 + (y_pos - piece_y)**2;
                
                -- 渲染逻辑
                if dist_sq < PIECE_RADIUS**2 then
                    piece_active <= '1';
                    if (cell_x = last_move_x) and (cell_y = last_move_y) then
                        is_last_move := '1';
                    else
                        is_last_move := '0';
                    end if;
                    -- 基础颜色设置
                    case cell_state is
                        when "01" => -- 黑棋
                            piece_red <= COLOR_BLACK;
                            piece_green <= COLOR_BLACK;
                            piece_blue <= COLOR_BLACK;
                        when "10" => -- 白棋
                            piece_red <= COLOR_WHITE;
                            piece_green <= COLOR_WHITE;
                            piece_blue <= COLOR_WHITE;
                        when others => -- 保留状态
                            null;
                    end case;
                    -- 最后一步高亮处理
                    if is_last_move = '1' then
                        if dist_sq > PIECE_RADIUS**2 and dist_sq<PIECE_RADIUS**2+2 then
                            piece_red <= COLOR_WHITE;
                            piece_green <= COLOR_HIGHLIGHT;
                            piece_blue <= COLOR_WHITE;
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;

