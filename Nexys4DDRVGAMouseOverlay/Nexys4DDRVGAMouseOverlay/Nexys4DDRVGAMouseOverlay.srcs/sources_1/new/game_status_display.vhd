library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_status_display is
    Port (
        clk         : in  STD_LOGIC;
        hcount      : in  STD_LOGIC_VECTOR(11 downto 0);
        vcount      : in  STD_LOGIC_VECTOR(11 downto 0);
        game_status : in  STD_LOGIC_VECTOR(1 downto 0);
        current_player : in STD_LOGIC;
        -- 输出颜色
        status_red   : out STD_LOGIC_VECTOR(3 downto 0);
        status_green : out STD_LOGIC_VECTOR(3 downto 0);
        status_blue  : out STD_LOGIC_VECTOR(3 downto 0);
        reset_red   : out STD_LOGIC_VECTOR(3 downto 0);
        reset_green : out STD_LOGIC_VECTOR(3 downto 0);
        reset_blue  : out STD_LOGIC_VECTOR(3 downto 0);
        status_active : out STD_LOGIC;
        reset_active: out std_logic
    );
end game_status_display;

architecture Behavioral of game_status_display is
    constant STATUS_AREA_X : integer := 50;
    constant STATUS_AREA_Y : integer := 50;
    constant STATUS_WIDTH : integer := 150;
    constant STATUS_HEIGHT : integer := 50;
    
    constant RESET_AREA_X : integer := 50;
    constant RESET_AREA_Y : integer := 150;
    constant RESET_WIDTH : integer := 150;
    constant RESET_HEIGHT : integer := 50;
    
    signal x_pos, y_pos : integer;
begin
    process(hcount, vcount)
    begin
        status_active <= '0';
        status_red <= (others => '0');
        status_green <= (others => '0');
        status_blue <= (others => '0');
        reset_active <= '0';
        reset_red <= (others => '0');
        reset_green <= (others => '0');
        reset_blue <= (others => '0');
        x_pos <= to_integer(unsigned(hcount));
        y_pos <= to_integer(unsigned(vcount));
        
        -- 检查是否在状态显示区域
        if x_pos >= STATUS_AREA_X and x_pos < STATUS_AREA_X + STATUS_WIDTH and
           y_pos >= STATUS_AREA_Y and y_pos < STATUS_AREA_Y + STATUS_HEIGHT then
            status_active <= '1';
            
            case game_status is
                when "00" => -- 游戏进行中
                    if current_player = '0' then
                        status_red <= "0000";
                        status_green <= "0000";
                        status_blue <= "1111"; -- 蓝色表示黑方回合
                    else
                        status_red <= "1111";
                        status_green <= "1111";
                        status_blue <= "1111"; -- 白色表示白方回合
                    end if;
                when "01" => -- 黑胜
                    status_red <= "0000";
                    status_green <= "1111";
                    status_blue <= "0000"; -- 绿色表示胜利
                when "10" => -- 白胜
                    status_red <= "1111";
                    status_green <= "0000";
                    status_blue <= "0000"; -- 红色表示胜利
                when others => -- 平局或其他
                    status_red <= "1111";
                    status_green <= "1111";
                    status_blue <= "0000"; -- 黄色表示平局
            end case;
        end if;
        
        --游戏重启显示代码
        if x_pos >= RESET_AREA_X and x_pos < RESET_AREA_X + RESET_WIDTH and
           y_pos >= RESET_AREA_Y and y_pos < RESET_AREA_Y + RESET_HEIGHT then
            reset_active <= '1';
            reset_red <= "1111";
            reset_green <= "0000";
            reset_blue <= "0000";   -- 红色
        end if;
    end process;
end Behavioral;
