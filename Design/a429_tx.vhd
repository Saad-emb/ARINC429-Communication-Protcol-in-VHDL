library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity a429_tx is 
	generic(
	clk_frequency : integer := 50_000_000;
	tranmssion_speed : integer := 100_000;
	frame_label : std_logic_vector(7 downto 0) := X"4F";
	ssm : std_logic_vector(1 downto 0) := "00"; -- Normal
	sdi : std_logic_vector(1 downto 0) := "00"
	);
	port (
	clk : in std_logic;
    reset : in std_logic;
	start : in std_logic;
    data_in : in std_logic_vector(18 downto 0);
	write_enable : in std_logic;  -- Signal to write to FIFO
	tx_high : out std_logic;
	tx_low : out std_logic);
end a429_tx;

architecture RTL of a429_tx is 

type mystates is (idle, read_data, label_state, sdi_state, data_state, ssm_state, parity, four_cycles_idle);
signal present_state :mystates;
signal next_state :mystates := idle;
signal s_data_in :STD_LOGIC_VECTOR (18 downto 0);
signal data_bit,data_bit_next :unsigned (5 downto 0);
signal s_tx_high :std_logic;
signal s_tx_low  :std_logic;
signal s_parity_bit :std_logic :='0';
signal done_signal : std_logic :='0';
signal clk_count, clk_count_next: POSITIVE;
signal calculated_parity :std_logic;

CONSTANT CLKS_PER_BIT: NATURAL := clk_frequency / tranmssion_speed;


-- FIFO Signals
signal fifo_data_in : std_logic_vector(18 downto 0);
signal fifo_data_out : std_logic_vector(18 downto 0);
signal fifo_empty : std_logic;
signal fifo_full : std_logic;
signal fifo_read_enable : std_logic;

component module_fifo_regs_no_flags is 
  generic (
    g_WIDTH : natural := 19;
    g_DEPTH : integer := 32
    );
  port (
    i_rst_sync : in std_logic;
    i_clk      : in std_logic;
 
    -- FIFO Write Interface
    i_wr_en   : in  std_logic;
    i_wr_data : in  std_logic_vector(g_WIDTH-1 downto 0);
    o_full    : out std_logic;
 
    -- FIFO Read Interface
    i_rd_en   : in  std_logic;
    o_rd_data : out std_logic_vector(g_WIDTH-1 downto 0);
    o_empty   : out std_logic
    );
end component;

begin 
fifo_inst : module_fifo_regs_no_flags port map (
	i_clk => clk,
	i_rst_sync => reset,
	i_wr_data => fifo_data_in,
	i_wr_en => write_enable,
	i_rd_en => fifo_read_enable,
	o_rd_data => fifo_data_out,
	o_empty => fifo_empty,
	o_full => fifo_full
);

process(clk)
begin
if(reset = '0') then
	present_state<=idle;
else
	if(rising_edge(clk)) then		  
		  present_state<=next_state;
		  clk_count <= clk_count_next;
		  data_bit<=data_bit_next;
		end if;
		end if;

end process;

process(clk,present_state)
	begin
	next_state<=present_state;
	clk_count_next <= clk_count;
	data_bit_next<= data_bit;
	
case (present_state) is

    when idle =>
        data_bit_next <= (others => '0');
		s_tx_low <= '0';
		s_tx_high <= '0';
        clk_count_next <= 1;
		-- ODD PARITY
		s_parity_bit <= '1';
        done_signal<='0';
		calculated_parity<='0';
        if(start='1'and fifo_empty='0') then
			s_data_in<=data_in;
			next_state<=read_data;
        else
			fifo_read_enable <='0';
			next_state <= idle;
        end if;
		
     when read_data =>  
		fifo_read_enable <='1';
        next_state <= label_state;
             
    when label_state =>
		fifo_read_enable <='0';
        if(data_bit< "01000") then
            next_state<=label_state;
            if(clk_count = CLKS_PER_BIT) then
				calculated_parity<='0';
				data_bit_next<=data_bit+1;
				clk_count_next <= 1;
            else
				if(frame_label(to_integer(7-data_bit))='0') then
					s_tx_low <= '1';
					s_tx_high <= '0';
				elsif(frame_label(to_integer(7-data_bit))='1') then
					s_tx_low <= '0';
					s_tx_high <= '1';
			    else 
					s_tx_low <= '0';
					s_tx_high <= '0';	
				end if;
			if (calculated_parity='0')then
				s_parity_bit <= s_parity_bit xor frame_label(to_integer(7- data_bit));
				calculated_parity<='1';
			end if;
            clk_count_next<=clk_count+1;
            end if;
		else
			data_bit_next <= (others => '0');
            next_state<=sdi_state; 
        end if;

    when sdi_state=>
        if(data_bit< "00010") then
            next_state<=sdi_state;
            if(clk_count = CLKS_PER_BIT) then
				calculated_parity<='0';
				data_bit_next<=data_bit+1;
				clk_count_next <= 1;
            else 
				if(sdi(to_integer(data_bit))='0') then
					s_tx_low <= '1';
					s_tx_high <= '0';
				elsif(sdi(to_integer(data_bit))='1') then
					s_tx_low <= '0';
					s_tx_high <= '1';
				else 
					s_tx_low <= '0';
					s_tx_high <= '0';	
				end if;
				if (calculated_parity='0')then
					s_parity_bit <= s_parity_bit xor sdi(to_integer(data_bit));
					calculated_parity<='1';

			end if;
            clk_count_next<=clk_count+1;
            end if;
        else
		    data_bit_next <= (others => '0');
            next_state<=data_state; 
        end if;
		
    when data_state =>
         if(data_bit< "10011") then
            next_state<=data_state;
            if(clk_count < CLKS_PER_BIT) then
				if(fifo_data_out(to_integer(data_bit))='0') then
					s_tx_low <= '1';
					s_tx_high <= '0';
				elsif(fifo_data_out(to_integer(data_bit))='1') then
					s_tx_low <= '0';
					s_tx_high <= '1';
				else 
					s_tx_low <= '0';
					s_tx_high <= '0';	
				end if;
				if (calculated_parity='0')then
					s_parity_bit <= s_parity_bit xor fifo_data_out(to_integer(data_bit));
					calculated_parity<='1';
			end if;
            clk_count_next<=clk_count+1;
            elsif (clk_count = CLKS_PER_BIT) then
				calculated_parity<='0';
				data_bit_next<=data_bit+1;
				clk_count_next <= 1;
            end if;
        else
		    data_bit_next <= (others => '0');
            next_state<=ssm_state; 
        end if;
		
    when ssm_state =>
         if(data_bit< "00010") then
            next_state<=ssm_state;
            if(clk_count = CLKS_PER_BIT) then
				calculated_parity<='0';
				data_bit_next<=data_bit+1;
				clk_count_next <= 1;
			else
				if(ssm(to_integer(data_bit))='0') then
					s_tx_low <= '1';
					s_tx_high <= '0';
				elsif(ssm(to_integer(data_bit))='1') then
					s_tx_low <= '0';
					s_tx_high <= '1';
				else 
					s_tx_low <= '0';
					s_tx_high <= '0';	
				end if;
				if (calculated_parity='0')then
					s_parity_bit <= s_parity_bit xor ssm(to_integer(data_bit));
					calculated_parity<='1';
				end if;
				clk_count_next<=clk_count+1;
            end if;
        else
		    data_bit_next <= (others => '0');
            next_state<=parity; 
        end if;
		
    when parity=>
        if(clk_count = CLKS_PER_BIT) then
		    data_bit_next <= (others => '0');
			next_state<=four_cycles_idle;
			clk_count_next <= 1;
			done_signal<='1';
         else
			-- ODD parity logic reversed
		 	if(s_parity_bit='0') then
				s_tx_low <= '1';
				s_tx_high <= '0';
			elsif(s_parity_bit='1') then
				s_tx_low <= '0';
				s_tx_high <= '1';
			else 
				s_tx_low <= '0';
				s_tx_high <= '0';	
			end if;     
         clk_count_next<=clk_count+1;  
         end if;
		 
    when four_cycles_idle =>
         if(data_bit< "00100") then
            next_state<=four_cycles_idle;
            if(clk_count = CLKS_PER_BIT) then
				data_bit_next<=data_bit+1;
				clk_count_next <= 1;
			else
				s_tx_low <= '0';
				s_tx_high <= '0';	
				clk_count_next<=clk_count+1;
            end if;
        else
		    data_bit_next <= (others => '0');
            next_state<=idle; 
        end if;
end case;
end process;

tx_low<=s_tx_low;
tx_high<=s_tx_high;
fifo_data_in<=data_in;


end RTL;