library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_vga_ctrl is
end tb_vga_ctrl;

architecture Behavioral of tb_vga_ctrl is
    -- 信号声明
    signal CLK_I         : STD_LOGIC := '0';
    signal VGA_HS_O      : STD_LOGIC;
    signal VGA_VS_O      : STD_LOGIC;
    signal VGA_RED_O     : STD_LOGIC_VECTOR(3 downto 0);
    signal VGA_GREEN_O   : STD_LOGIC_VECTOR(3 downto 0);
    signal VGA_BLUE_O    : STD_LOGIC_VECTOR(3 downto 0);
    signal PS2_CLK       : STD_LOGIC := '1';
    signal PS2_DATA      : STD_LOGIC := '1';

    -- 实例化被测模块
    component vga_ctrl
        Port (
            CLK_I        : in  STD_LOGIC;
            VGA_HS_O     : out STD_LOGIC;
            VGA_VS_O     : out STD_LOGIC;
            VGA_RED_O    : out STD_LOGIC_VECTOR(3 downto 0);
            VGA_GREEN_O  : out STD_LOGIC_VECTOR(3 downto 0);
            VGA_BLUE_O   : out STD_LOGIC_VECTOR(3 downto 0);
            PS2_CLK      : inout STD_LOGIC;
            PS2_DATA     : inout STD_LOGIC
        );
    end component;

begin
    uut: vga_ctrl
        Port map (
            CLK_I        => CLK_I,
            VGA_HS_O     => VGA_HS_O,
            VGA_VS_O     => VGA_VS_O,
            VGA_RED_O    => VGA_RED_O,
            VGA_GREEN_O  => VGA_GREEN_O,
            VGA_BLUE_O   => VGA_BLUE_O,
            PS2_CLK      => PS2_CLK,
            PS2_DATA     => PS2_DATA
        );

    -- 时钟生成（148.5MHz）
    CLK_I <= not CLK_I after 3.369 ns; -- 周期约148.5MHz (6.738ns/周期 → 3.369ns半周期)

    -- 模拟鼠标输入（示例：固定点击位置）
    PS2_CLK <= '0' after 10 ns, '1' after 20 ns, '0' after 30 ns, '1' after 40 ns; -- 模拟PS/2时钟
    PS2_DATA <= '1' after 15 ns, '0' after 25 ns; -- 模拟鼠标左键点击
end Behavioral;