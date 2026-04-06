library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.std_logic_unsigned.all;
use ieee.math_real.all;

entity vga_ctrl is

    generic(
        BSIZE : integer := 9  -- 添加通用参数[4]
    );
    
    Port ( CLK_I : in STD_LOGIC;
           VGA_HS_O : out STD_LOGIC;
           VGA_VS_O : out STD_LOGIC;
           VGA_RED_O : out STD_LOGIC_VECTOR (3 downto 0);
           VGA_BLUE_O : out STD_LOGIC_VECTOR (3 downto 0);
           VGA_GREEN_O : out STD_LOGIC_VECTOR (3 downto 0);
           PS2_CLK      : inout STD_LOGIC;
           PS2_DATA     : inout STD_LOGIC
           );
end vga_ctrl;

architecture Behavioral of vga_ctrl is

  COMPONENT MouseCtl
  GENERIC
  (
     SYSCLK_FREQUENCY_HZ : integer := 100000000;
     CHECK_PERIOD_MS     : integer := 500;
     TIMEOUT_PERIOD_MS   : integer := 100
  );
  PORT(
      clk : IN std_logic;
      rst : IN std_logic;
      value : IN std_logic_vector(11 downto 0);
      setx : IN std_logic;
      sety : IN std_logic;
      setmax_x : IN std_logic;
      setmax_y : IN std_logic;    
      ps2_clk : INOUT std_logic;
      ps2_data : INOUT std_logic;      
      xpos : OUT std_logic_vector(11 downto 0);
      ypos : OUT std_logic_vector(11 downto 0);
      zpos : OUT std_logic_vector(3 downto 0);
      left : OUT std_logic;
      middle : OUT std_logic;
      right : OUT std_logic;
      new_event : OUT std_logic
      );
  END COMPONENT;

  COMPONENT MouseDisplay
  PORT(
      pixel_clk : IN std_logic;
      xpos : IN std_logic_vector(11 downto 0);
      ypos : IN std_logic_vector(11 downto 0);
      hcount : IN std_logic_vector(11 downto 0);
      vcount : IN std_logic_vector(11 downto 0);          
      enable_mouse_display_out : OUT std_logic;
      red_out : OUT std_logic_vector(3 downto 0);
      green_out : OUT std_logic_vector(3 downto 0);
      blue_out : OUT std_logic_vector(3 downto 0)
      );
  END COMPONENT;

component clk_wiz_0
port
 (-- Clock in ports
  clk_in1           : in     std_logic;
  -- Clock out ports
  clk_out1          : out    std_logic;
   reset : in std_logic
 );
end component;

component text_renderer is
    Port (
        clk         : in  STD_LOGIC;
        hcount      : in  STD_LOGIC_VECTOR(11 downto 0); -- VGA水平计数器
        vcount      : in  STD_LOGIC_VECTOR(11 downto 0); -- VGA垂直计数器
        x_start       : in  integer; -- 字符起始X坐标
        y_start       : in  integer; -- 字符起始Y坐标
        char_active : out STD_LOGIC
    );
 end component;
  --***1920x1080@60Hz***--
  constant FRAME_WIDTH : natural := 1920;
  constant FRAME_HEIGHT : natural := 1080;
  
  constant H_FP : natural := 88;    -- H front porch width (pixels)
  constant H_PW : natural := 44;    -- H sync pulse width (pixels)
  constant H_BP : natural := 148;   -- H back porch width (pixels)
  constant H_MAX : natural := 2200; -- H total period (pixels)
  
  constant V_FP : natural := 4;     -- V front porch width (lines)
  constant V_PW : natural := 5;     -- V sync pulse width (lines)
  constant V_BP : natural := 36;    -- V back porch width (lines)
  constant V_MAX : natural := 1125; -- V total period (lines)
  
  constant H_POL : std_logic := '1';
  constant V_POL : std_logic := '1';
  
-- 新增常量定义
constant LINE_SPACING : integer := 80;  -- 线条间隔
constant LINE_WIDTH : integer := 4;     -- 线宽
constant BG_COLOR     : std_logic_vector(3 downto 0) := "1110";  -- 浅黄色（RGB全高）
constant LINE_COLOR   : std_logic_vector(3 downto 0) := "0000";  -- 黑色
  -------------------------------------------------------------------------
  
  -- VGA Controller specific signals: Counters, Sync, R, G, B
  
  -------------------------------------------------------------------------
  -- Pixel clock, in this case 148.5 MHz (for 1920x1080@60Hz)
  signal pxl_clk : std_logic;
  -- The active signal is used to signal the active region of the screen (when not blank)
  signal active  : std_logic;
  
  -- Horizontal and Vertical counters
  signal h_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');
  signal v_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');
  
  -- Pipe Horizontal and Vertical Counters
  signal h_cntr_reg_dly   : std_logic_vector(11 downto 0) := (others => '0');
  signal v_cntr_reg_dly   : std_logic_vector(11 downto 0) := (others => '0');
  
  -- Horizontal and Vertical Sync
  signal h_sync_reg : std_logic := not(H_POL);
  signal v_sync_reg : std_logic := not(V_POL);
  -- Pipe Horizontal and Vertical Sync
  signal h_sync_reg_dly : std_logic := not(H_POL);
  signal v_sync_reg_dly : std_logic :=  not(V_POL);
  
  -- VGA R, G and B signals coming from the main multiplexers
  signal vga_red_cmb   : std_logic_vector(3 downto 0);
  signal vga_green_cmb : std_logic_vector(3 downto 0);
  signal vga_blue_cmb  : std_logic_vector(3 downto 0);
  --The main VGA R, G and B signals, validated by active
  signal vga_red    : std_logic_vector(3 downto 0);
  signal vga_green  : std_logic_vector(3 downto 0);
  signal vga_blue   : std_logic_vector(3 downto 0);
  -- Register VGA R, G and B signals
  signal vga_red_reg   : std_logic_vector(3 downto 0) := (others =>'0');
  signal vga_green_reg : std_logic_vector(3 downto 0) := (others =>'0');
  signal vga_blue_reg  : std_logic_vector(3 downto 0) := (others =>'0');
  
  -------------------------------------------------------------------------
  --Mouse pointer signals
  -------------------------------------------------------------------------
  
  -- Mouse data signals
  signal MOUSE_X_POS: std_logic_vector (11 downto 0);
  signal MOUSE_Y_POS: std_logic_vector (11 downto 0);
  signal MOUSE_X_POS_REG: std_logic_vector (11 downto 0);
  signal MOUSE_Y_POS_REG: std_logic_vector (11 downto 0);
  
  -- Mouse cursor display signals
  signal mouse_cursor_red    : std_logic_vector (3 downto 0) := (others => '0');
  signal mouse_cursor_blue   : std_logic_vector (3 downto 0) := (others => '0');
  signal mouse_cursor_green  : std_logic_vector (3 downto 0) := (others => '0');
  -- Mouse cursor enable display signals
  signal enable_mouse_display:  std_logic;
  -- Registered Mouse cursor display signals
  signal mouse_cursor_red_dly   : std_logic_vector (3 downto 0) := (others => '0');
  signal mouse_cursor_blue_dly  : std_logic_vector (3 downto 0) := (others => '0');
  signal mouse_cursor_green_dly : std_logic_vector (3 downto 0) := (others => '0');
  -- Registered Mouse cursor enable display signals
  signal enable_mouse_display_dly  :  std_logic;
  
  -----------------------------------------------------------
  -- Signals for generating the background (moving colorbar)
  -----------------------------------------------------------
  signal cntDyn                : integer range 0 to 2**28-1; -- counter for generating the colorbar
  signal intHcnt                : integer range 0 to H_MAX - 1;
  signal intVcnt                : integer range 0 to V_MAX - 1;
  -- Colorbar red, greeen and blue signals
  signal bg_red                 : std_logic_vector(3 downto 0):= "1111";
  signal bg_blue             : std_logic_vector(3 downto 0) := "1111";
  signal bg_green             : std_logic_vector(3 downto 0):= (others => '0');
  -- Pipe the colorbar red, green and blue signals
  signal bg_red_dly            : std_logic_vector(3 downto 0) := "1111";
  signal bg_green_dly        : std_logic_vector(3 downto 0) := "1111";
  signal bg_blue_dly        : std_logic_vector(3 downto 0) := (others => '0');
  
                          signal checkerboard_active : std_logic;
  
                                 -- 新增棋盘生成逻辑（在原有代码的背景生成部分之后添加）
                            signal checkerboard_red   : std_logic_vector(3 downto 0);
                            signal checkerboard_green : std_logic_vector(3 downto 0);
                            signal checkerboard_blue  : std_logic_vector(3 downto 0);


                                            -- 新增信号声明
                                                signal board_state : STD_LOGIC_VECTOR( BSIZE*BSIZE*2-1 downto 0);
                                                --!!!!!!
                                                signal current_player : STD_LOGIC;
                                                signal game_status : STD_LOGIC_VECTOR(1 downto 0);
                                                signal last_move_x : INTEGER ;
                                                signal last_move_y : INTEGER ;
                                                
                                                -- 棋子显示信号
                                                signal piece_red, piece_green, piece_blue : STD_LOGIC_VECTOR(3 downto 0);
                                                signal piece_active : STD_LOGIC;
                                                
                                                -- 状态显示信号
                                                signal status_red, status_green, status_blue : STD_LOGIC_VECTOR(3 downto 0);
                                                signal status_active : STD_LOGIC;
                                                signal reset_active: std_logic;
                                                signal reset_red, reset_green, reset_blue : STD_LOGIC_VECTOR(3 downto 0);
                                                
                                                -- 鼠标点击信号
                                                signal left_click_reg : STD_LOGIC := '0';
                                                signal left_click : std_logic;  -- 声明 left_click 信号
                                                signal game_reset: std_logic;
                                                   --字符串信号
                                                signal char_active: std_logic;
                                                signal R_x: integer;
                                                signal R_y: integer;
begin
                                      -- 实例化游戏控制器
                                        game_ctrl_inst: entity work.game_controller
                                         generic map(
                                                        BSIZE => BSIZE  -- 传递通用参数[4]
                                                    )
                                        
                                        port map(
                                            clk => pxl_clk,
                                            reset => '0',
                                            mouse_x => MOUSE_X_POS_REG,
                                            mouse_y => MOUSE_Y_POS_REG,
                                            left_click => left_click_reg,
                                            board_state => board_state,
                                            current_player => current_player,
                                            game_status => game_status,
                                            last_move_x => last_move_x,
                                            last_move_y => last_move_y
                                        );
                                        
                                        -- 实例化棋子渲染
                                        piece_render_inst: entity work.piece_render
                                         generic map(
                                                        BSIZE => BSIZE  -- 传递通用参数[4]
                                                    )
                                        port map(
                                            clk => pxl_clk,
                                            hcount => h_cntr_reg_dly,
                                            vcount => v_cntr_reg_dly,
                                            board_state => board_state,
                                            current_player => current_player,
                                            last_move_x => last_move_x,
                                            last_move_y => last_move_y,
                                            piece_red => piece_red,
                                            piece_green => piece_green,
                                            piece_blue => piece_blue,
                                            piece_active => piece_active
                                        );
                                        
                                        -- 实例化状态显示
                                        status_display_inst: entity work.game_status_display
                                        port map(
                                            clk => pxl_clk,
                                            hcount => h_cntr_reg_dly,
                                            vcount => v_cntr_reg_dly,
                                            game_status => game_status,
                                            current_player => current_player,
                                            status_red => status_red,
                                            status_green => status_green,
                                            status_blue => status_blue,
                                            reset_red=>reset_red,
                                            reset_green=>reset_green,
                                            reset_blue=>reset_blue,
                                            status_active => status_active,
                                            reset_active=>reset_active
                                        );
      String_R:  text_renderer
        PORT MAP 
        (
        clk       =>pxl_clk,
        hcount    => h_cntr_reg_dly, -- VGA水平计数器
        vcount    => v_cntr_reg_dly,-- VGA垂直计数器
        x_start   => 55 , -- 字符起始X坐标
        y_start    => 151, -- 字符起始Y坐标
        char_active =>char_active 
        );
                                   
  clk_wiz_0_inst : clk_wiz_0
  port map
   (
    clk_in1 => CLK_I,
     reset   => '0' , -- 添加复位信号（接地）
    clk_out1 => pxl_clk);
  
    
    ----------------------------------------------------------------------------------
    -- Mouse Controller
    ----------------------------------------------------------------------------------
       Inst_MouseCtl: MouseCtl
       GENERIC MAP
    (
       SYSCLK_FREQUENCY_HZ => 148500000,  -- Updated to match new pixel clock
       CHECK_PERIOD_MS     => 500,
       TIMEOUT_PERIOD_MS   => 100
    )
       PORT MAP
       (
          clk            => pxl_clk,
          rst            => '0',
          xpos           => MOUSE_X_POS,
          ypos           => MOUSE_Y_POS,
          zpos           => open,
          left           => left_click,
          middle         => open,
          right          => open,
          new_event      => open,
          value          => x"000",
          setx           => '0',
          sety           => '0',
          setmax_x       => '0',
          setmax_y       => '0',
          ps2_clk        => PS2_CLK,
          ps2_data       => PS2_DATA
       );
       
       ---------------------------------------------------------------
       
       -- Generate Horizontal, Vertical counters and the Sync signals
       
       ---------------------------------------------------------------
         -- Horizontal counter
         process (pxl_clk)
         begin
           if (rising_edge(pxl_clk)) then
             if (h_cntr_reg = (H_MAX - 1)) then
               h_cntr_reg <= (others =>'0');
             else
               h_cntr_reg <= h_cntr_reg + 1;
             end if;
           end if;
         end process;
         -- Vertical counter
         process (pxl_clk)
         begin
           if (rising_edge(pxl_clk)) then
             if ((h_cntr_reg = (H_MAX - 1)) and (v_cntr_reg = (V_MAX - 1))) then
               v_cntr_reg <= (others =>'0');
             elsif (h_cntr_reg = (H_MAX - 1)) then
               v_cntr_reg <= v_cntr_reg + 1;
             end if;
           end if;
         end process;
         -- Horizontal sync
         process (pxl_clk)
         begin
           if (rising_edge(pxl_clk)) then
             if (h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) and (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1)) then
               h_sync_reg <= H_POL;
             else
               h_sync_reg <= not(H_POL);
             end if;
           end if;
         end process;
         -- Vertical sync
         process (pxl_clk)
         begin
           if (rising_edge(pxl_clk)) then
             if (v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) and (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1)) then
               v_sync_reg <= V_POL;
             else
               v_sync_reg <= not(V_POL);
             end if;
           end if;
         end process;
         
       --------------------
       
       -- The active 
       
       --------------------  
         -- active signal
         active <= '1' when h_cntr_reg_dly < FRAME_WIDTH and v_cntr_reg_dly < FRAME_HEIGHT
                   else '0';
       
       
       --------------------
       
       -- Register Inputs
       
       --------------------
    register_inputs: process (pxl_clk)
    begin
        if (rising_edge(pxl_clk)) then  
          if v_sync_reg = V_POL then
            MOUSE_X_POS_REG <= MOUSE_X_POS;
            MOUSE_Y_POS_REG <= MOUSE_Y_POS;
          end if;   
        end if;
    end process register_inputs;
     ---------------------------------------
     
     -- Generate moving colorbar background
     
     ---------------------------------------
     
     generate_checkerboard: process(pxl_clk)
    -- 棋盘参数定义 --
    constant GRID_SIZE     : integer := BSIZE;    -- 5x5棋盘
    constant CELL_SIZE     : integer := 100;  -- 每个单元格100像素
    constant LINE_WIDTH    : integer := 2;    -- 网格线宽度2像素
    constant BOARD_WIDTH   : integer := GRID_SIZE*(CELL_SIZE + LINE_WIDTH) - LINE_WIDTH;
    constant BOARD_HEIGHT  : integer := BOARD_WIDTH;
    variable board_offset_x : integer;  
    variable board_offset_y : integer;
    variable local_x       : integer;
    variable local_y       : integer;
begin
    if rising_edge(pxl_clk) then
        -- 计算偏移量（每次更新）--
        board_offset_x := (FRAME_WIDTH - BOARD_WIDTH)/2;
        board_offset_y := (FRAME_HEIGHT - BOARD_HEIGHT)/2;
        
        -- 转换计数器为整数 --
        intHcnt <= conv_integer(unsigned(h_cntr_reg_dly));
        intVcnt <= conv_integer(unsigned(v_cntr_reg_dly));
        
  -- 默认黄色背景（棋盘外）--
        bg_red   <= "1111";   -- 黄色
        bg_green <= "1111";
        bg_blue  <= "0000";
        checkerboard_active <= '0'; 
        
        -- 检查是否在棋盘区域内 --
        if (intHcnt >= board_offset_x and intHcnt <= board_offset_x + BOARD_WIDTH and
            intVcnt >= board_offset_y and intVcnt <= board_offset_y + BOARD_HEIGHT) then
            checkerboard_active <= '1'; -- 标记为棋盘区域
            
            -- 计算相对坐标 --
            local_x := intHcnt - board_offset_x;
            local_y := intVcnt - board_offset_y;
            
            -- 网格线生成逻辑 --
            if ( (local_x mod (CELL_SIZE + LINE_WIDTH)) < LINE_WIDTH or
                 (local_y mod (CELL_SIZE + LINE_WIDTH)) < LINE_WIDTH ) then
                -- 白色网格线 --
                checkerboard_red   <= "1111";
                checkerboard_green <= "1111";
                checkerboard_blue  <= "1111";
            else
                -- 灰色单元格 --
                checkerboard_red   <= "1000";
                checkerboard_green <= "1000";
                checkerboard_blue  <= "1000";
            end if;
        end if;
    end if;
end process generate_checkerboard;

     
     
     ----------------------------------
     
     -- Mouse Cursor display instance
     
     ----------------------------------
        Inst_MouseDisplay: MouseDisplay
        PORT MAP 
        (
           pixel_clk   => pxl_clk,
           xpos        => MOUSE_X_POS_REG, 
           ypos        => MOUSE_Y_POS_REG,
           hcount      => h_cntr_reg,
           vcount      => v_cntr_reg,
           enable_mouse_display_out  => enable_mouse_display,
           red_out     => mouse_cursor_red,
           green_out   => mouse_cursor_green,
           blue_out    => mouse_cursor_blue
        );
    
    ---------------------------------------------------------------------------------------------------
    
    -- Register Outputs coming from the displaying components and the horizontal and vertical counters
    
    ---------------------------------------------------------------------------------------------------
      process (pxl_clk)
      begin
        if (rising_edge(pxl_clk)) then
            bg_red_dly            <= bg_red;
            bg_green_dly        <= bg_green;
            bg_blue_dly            <= bg_blue;
            mouse_cursor_red_dly    <= mouse_cursor_red;
            mouse_cursor_blue_dly   <= mouse_cursor_blue;
            mouse_cursor_green_dly  <= mouse_cursor_green;
            
            enable_mouse_display_dly   <= enable_mouse_display;
            
            h_cntr_reg_dly <= h_cntr_reg;
            v_cntr_reg_dly <= v_cntr_reg;

        end if;
      end process;
      
      
                                              -- 鼠标点击检测
                                        process(pxl_clk)
                                        begin
                                            if rising_edge(pxl_clk) then
                                                left_click_reg <= '0';
                                                if left_click = '1' then
                                                    left_click_reg <= '1';
                                                end if;
                                            end if;
                                        end process;

    ----------------------------------
    
    -- VGA Output Muxing
    
    ----------------------------------
           
           
                                               -- 修改输出多路复用器
--                                    vga_red <=   mouse_cursor_red_dly when enable_mouse_display_dly = '1' else
--                                                 piece_red when piece_active = '1' else
--                                                 status_red when status_active = '1' else
--                                                 checkerboard_red when (active = '1') else
--                                                 bg_red_dly;
                                    vga_red <=   mouse_cursor_red_dly when enable_mouse_display_dly = '1' else
                                    "0000" when char_active='1' else
                                                 piece_red when piece_active = '1' else
                                                 status_red when status_active = '1' else
                                                 checkerboard_red when checkerboard_active = '1'  else
                                                 reset_red when reset_active='1' else -- 仅棋盘区域显示
                                                 bg_red_dly;
                                    vga_green <= mouse_cursor_green_dly when enable_mouse_display_dly = '1' else
                                    "0000" when char_active='1' else
                                                 piece_green when piece_active = '1' else
                                                 status_green when status_active = '1' else
                                                 checkerboard_green when (checkerboard_active = '1') else
                                                 reset_green when reset_active='1' else
                                                 bg_green_dly;
                                    vga_blue <=  mouse_cursor_blue_dly when enable_mouse_display_dly = '1' else
                                    "0000" when char_active='1' else
                                                 piece_blue when piece_active = '1' else
                                                 status_blue when status_active = '1' else
                                                 checkerboard_blue when (checkerboard_active = '1') else
                                                 reset_blue when reset_active='1' else
                                                 bg_blue_dly;
    ------------------------------------------------------------
    -- Turn Off VGA RBG Signals if outside of the active screen
    -- Make a 4-bit AND logic with the R, G and B signals
    ------------------------------------------------------------
    vga_red_cmb <= (active & active & active & active) and vga_red;
    vga_green_cmb <= (active & active & active & active) and vga_green;
    vga_blue_cmb <= (active & active & active & active) and vga_blue;
    
    
    -- Register Outputs
     process (pxl_clk)
     begin
       if (rising_edge(pxl_clk)) then
    
         v_sync_reg_dly <= v_sync_reg;
         h_sync_reg_dly <= h_sync_reg;
         vga_red_reg    <= vga_red_cmb;
         vga_green_reg  <= vga_green_cmb;
         vga_blue_reg   <= vga_blue_cmb;      
       end if;
     end process;
    
     -- Assign outputs
     VGA_HS_O     <= h_sync_reg_dly;
     VGA_VS_O     <= v_sync_reg_dly;
     VGA_RED_O    <= vga_red_reg;
     VGA_GREEN_O  <= vga_green_reg;
     VGA_BLUE_O   <= vga_blue_reg;

end Behavioral;
