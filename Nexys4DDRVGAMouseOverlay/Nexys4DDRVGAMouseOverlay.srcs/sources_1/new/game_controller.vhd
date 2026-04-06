-- 修改后的游戏控制器（game_controller.vhd）--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_controller is

    generic(
        BSIZE : integer  -- 添加通用参数[4]
    );
    
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;   
        mouse_x     : in  STD_LOGIC_VECTOR(11 downto 0);
        mouse_y     : in  STD_LOGIC_VECTOR(11 downto 0);
        left_click  : in  STD_LOGIC;
        board_state : out STD_LOGIC_VECTOR(BSIZE*BSIZE*2 -1 downto 0);
        game_status : out STD_LOGIC_VECTOR(1 downto 0);
        current_player : out STD_LOGIC;
        last_move_x : inout INTEGER ;
        last_move_y : inout INTEGER 
        
    );
end game_controller;

architecture Behavioral of game_controller is
    -- 新增棋盘坐标转换常数 --
    constant GRID_SIZE     : integer := BSIZE;    -- 5x5棋盘
    constant CELL_SIZE     : integer := 100;  -- 每个单元格100像素
    constant LINE_WIDTH    : integer := 2;    -- 网格线宽度2像素
    constant BOARD_WIDTH   : integer := GRID_SIZE*(CELL_SIZE + LINE_WIDTH) - LINE_WIDTH;
    constant BOARD_HEIGHT  : integer := BOARD_WIDTH;
    constant FRAME_WIDTH : natural := 1920;
    constant FRAME_HEIGHT : natural := 1080;
    
    constant BOARD_ORIGIN_X : integer := (FRAME_WIDTH - BOARD_WIDTH)/2;
    constant BOARD_ORIGIN_Y : integer := (FRAME_HEIGHT - BOARD_HEIGHT)/2;
    --游戏重开常数
    constant RESET_AREA_X : integer := 50;
    constant RESET_AREA_Y : integer := 150;
    constant RESET_WIDTH : integer := 150;
    constant RESET_HEIGHT : integer := 50;


    -- 优化后的棋盘存储 --
    type board_array is array (0 to BSIZE -1 , 0 to BSIZE - 1) of STD_LOGIC_VECTOR(1 downto 0);
    signal board : board_array := (others => (others => "00"));
    
    -- 其他信号优化 --
    signal player_turn : STD_LOGIC := '0'; -- 使用单bit表示玩家
    signal valid_click : STD_LOGIC;
    signal game_reset: std_logic;
    signal game_reset_tmp:std_logic;
    signal flag:std_logic :='0';
        signal num_step:integer:=0;--记录步数

 function check_win(
        x, y : integer;
        --player : STD_LOGIC;
        brd : board_array;
        constant player_code : std_logic_vector(1 downto 0) 

    ) return boolean is
        variable count : integer;
     
    -- 根据 player 的值动态生成比较值 "01" 或 "10"
    
    begin
        -- 检查四个方向的连续棋子 --
        
        -- 水平方向 --
        count := 1;
        -- 向左检查
        for i in 1 to 4 loop
            exit when (x - i) < 0;
            exit when brd(x - i, y) /= player_code  ;
            exit when brd(x - i, y)(1 downto 0) = "00";
            count := count + 1;
        end loop;
        -- 向右检查
        for i in 1 to 4 loop
            exit when (x + i) > BSIZE -1;
            exit when brd(x + i, y)(1 downto 0) /= player_code  ;
           exit when brd(x + i, y)(1 downto 0) = "00";
            count := count + 1;
        end loop;
        if count >= 5 then return true; end if;

        -- 垂直方向 --
        count := 1;
        -- 向上检查
        for i in 1 to 4 loop
            exit when (y - i) < 0;
            exit when brd(x, y - i)(1 downto 0) /= player_code ;
            exit when brd(x, y - i)(1 downto 0) = "00";
            count := count + 1;
        end loop;
        -- 向下检查
        for i in 1 to 4 loop
            exit when (y + i) > BSIZE -1;
            exit when brd(x, y + i)(1 downto 0) /= player_code  ;
            exit when brd(x, y + i)(1 downto 0) = "00";
            count := count + 1;
        end loop;
        if count >= 5 then return true; end if;

        -- 主对角线（左上-右下）
        count := 1;
        -- 左上检查
        for i in 1 to 4 loop
            exit when (x - i) < 0 or (y - i) < 0;
            exit when brd(x - i, y - i)(1 downto 0) /= player_code  ;
            exit when brd(x - i, y - i)(1 downto 0) = "00";
            count := count + 1;
        end loop;
        -- 右下检查
        for i in 1 to 4 loop
            exit when (x + i) > BSIZE -1 or (y + i) > BSIZE -1;
            exit when brd(x + i, y + i)(1 downto 0) /= player_code;
             exit when brd(x + i, y + i)(1 downto 0) = "00";
            count := count + 1;
        end loop;
        if count >= 5 then return true; end if;

        -- 副对角线（右上-左下）
        count := 1;
        -- 右上检查
        for i in 1 to 4 loop
            exit when (x + i) > BSIZE -1 or (y - i) < 0;
            exit when brd(x + i, y - i)(1 downto 0) /= player_code ;
            exit when brd (x + i, y - i)(1 downto 0) = "00";
            count := count + 1;
        end loop;
        -- 左下检查
        for i in 1 to 4 loop
            exit when (x - i) < 0 or (y + i) > BSIZE -1;
            exit when brd(x - i, y + i)(1 downto 0) /= player_code  ;
           exit when brd(x - i, y + i)(1 downto 0) = "00";
            count := count + 1;
        end loop;
        if count >= 5 then return true; end if;

        return false;
    end function;   

begin
-- 坐标转换优化 --
process(mouse_x, mouse_y)
    variable pos_x : integer;
    variable pos_y : integer;
    variable tmp_x :integer;
    variable tmp_y: integer;
begin
    pos_x := (to_integer(unsigned(mouse_x)) - BOARD_ORIGIN_X) / (CELL_SIZE+LINE_WIDTH);
    pos_y := (to_integer(unsigned(mouse_y)) - BOARD_ORIGIN_Y) / (CELL_SIZE+LINE_WIDTH);
    
    -- 边界检查 --
    if (to_integer(unsigned(mouse_x)) - BOARD_ORIGIN_X) <0 then pos_x := -1;
    elsif pos_x > BSIZE -1 then pos_x := BSIZE;
    end if;
    if (to_integer(unsigned(mouse_y)) - BOARD_ORIGIN_Y) < 0 then pos_y := -1;
    elsif pos_y > BSIZE -1 then pos_y :=BSIZE;
    end if;
    -- 检测是否点击复位区域
    tmp_x := to_integer(unsigned(mouse_x));
    tmp_y := to_integer(unsigned(mouse_y));
    if tmp_x >= RESET_AREA_X and 
       tmp_x < RESET_AREA_X + RESET_WIDTH and
       tmp_y >= RESET_AREA_Y and
       tmp_y < RESET_AREA_Y + RESET_HEIGHT then
        game_reset_tmp <= '1';
    else
        game_reset_tmp <= '0';
    end if;
    last_move_x <= pos_x;
    last_move_y <= pos_y;
end process;

process(clk)
begin
if num_step=BSIZE*BSIZE and flag='0' then
             game_status<="01";    
             end if;
    if rising_edge(clk) then
--        if reset = '1' then
--          board <= (others => (others => "00"));
--          player_turn <= '0';
--          game_reset <= '0'; 
--          game_status<="00";
             if valid_click = '1' then
                -- 仅在非复位状态下处理落子逻辑
                if game_reset_tmp = '1' then
                    board<=(others => (others => "00"));
                    player_turn <= '0';
                    current_player<='0';
                    flag<='0';
                    game_reset<='1';    
                    game_status<="00";  
                    num_step<=0;              
               elsif last_move_y/=-1 and last_move_y/=BSIZE and last_move_x/=-1 and last_move_x/=BSIZE and flag='0' then
                    if last_move_x>=0 and last_move_y >= 0 and last_move_x<=BSIZE -1 and last_move_y <=BSIZE -1  then
                        game_reset<='0';
                        if board(last_move_x, last_move_y) = "00" then
                        if player_turn = '0' then
                            board(last_move_x, last_move_y) <= "01";  -- 黑棋
                        elsif player_turn = '1' then
                            board(last_move_x, last_move_y) <= "10";  -- 白棋
                        end if;
                        player_turn <= not player_turn;
                        current_player <= not player_turn;
                        if player_turn = '0'and flag='0' then
            if check_win(last_move_x, last_move_y, board,"01") then
                        game_status <= "1"&player_turn;
                        flag<='1';
             else 
             --num_of_step <= num_of_step+1;
             game_status<="00";
             --else game_status<="01";
             end if;
             end if;
              if player_turn = '1'and flag='0' then
            if check_win(last_move_x, last_move_y,  board,"10") then
                        game_status <= "11";
                        flag<='1';
             else 
             --num_of_step <= num_of_step+1;
             game_status<="00";
             --else game_status<="01";
             end if;
             end if;
                          num_step<=num_step+1;

                        end if;                 
                    end if;      
               end if;
                    
        end if;
end if;
end process;

-- 棋盘状态序列化 --
process(board, game_reset)
begin
    for i in 0 to BSIZE -1 loop
        for j in 0 to BSIZE -1 loop
            board_state((i*BSIZE+j)*2+1 downto (i*BSIZE+j)*2) <= board(j,i);
        end loop;
    end loop;
end process;

-- 新增输入消抖逻辑 --
process(clk)
    variable click_cnt : integer range 0 to 100;
begin
    if rising_edge(clk) then
        if left_click = '1' then
            click_cnt := click_cnt + 1;
            valid_click <= '0';
            if click_cnt = 100 then
                valid_click <= '1';
            end if;
        else
            click_cnt := 0;
            valid_click <= '0';
        end if;
    end if;
end process;

end Behavioral;
