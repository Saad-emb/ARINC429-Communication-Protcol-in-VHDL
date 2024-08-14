library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity arinc_tx_tb is
end arinc_tx_tb;

architecture RTL of arinc_tx_tb is 




COMPONENT a429_tx
	generic(
	clk_frequency : integer := 50_000_000; -- 50mhz
	tranmssion_speed : integer := 100_000;  -- 100 kb/s
	frame_label : std_logic_vector(7 downto 0) := X"4F";
	ssm : std_logic_vector(1 downto 0) := "11"; -- Normal Operation BNR format
	sdi : std_logic_vector(1 downto 0) := "00" -- All systems
	);
	port (
	clk : in std_logic;
    reset : in std_logic;
	start : in std_logic;
    data_in : in std_logic_vector(18 downto 0);
	write_enable : in std_logic; 
	tx_high : out std_logic;
	tx_low : out std_logic);
end component;
signal data_in : std_logic_vector(18 downto 0);
signal clk,reset,start,write_enable, tx_high,tx_low  : std_logic ;
begin 
u0: a429_tx port map 
(
clk=>clk,
data_in=>data_in,
write_enable=>write_enable,
start=>start,
reset=>reset,
tx_high=>tx_high,
tx_low=>tx_low

);

process
begin
clk<='0';
wait for 10 ns;
clk<='1';
wait for 10 ns;
end process;
 process
begin
data_in<="000"& X"FFFF";
write_enable<='0';
start<='0';
wait for 240 ns;
write_enable<='1';
wait for 20 ns;
data_in<="001"& X"0000";
wait for 20 ns;
data_in<="001"& X"5555";
wait for 20 ns;
write_enable<='0';
wait for 200 ns;
start<='1';
wait for 2 ms;
end process;

 process
begin
reset<='0';
wait for 100 ns;
reset<='1';
wait for 10 ms;

end process;



end RTL;