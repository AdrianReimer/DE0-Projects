LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_signed.ALL;

ENTITY Aufgabe_3 IS 
	PORT(	
		CLOCK_50 : in std_logic;
		i2c_clk : out std_logic;
		i2c_sda : inout std_logic;
		reset : in std_logic;
		LEDG : out std_logic_vector(9 downto 0);
		BUTTON : in std_logic;
		HEX0_D : out std_logic_vector(6 downto 0)
	);
	end Aufgabe_3;
	
	ARCHITECTURE arch of Aufgabe_3 is
	constant CLOCK_FREQ : integer := 400; 
	SIGNAL counter : integer := 0;
	SIGNAL counter_stp : integer := 0;
	SIGNAL stp_clk : std_logic;
	TYPE State_type IS (Init_State, Addressing, readWrite, Acknow, Acknow2, Data, Processing, ZState, EndState);
	SIGNAL State : State_type;
	SIGNAl factor : integer := 1000;
	SIGNAL idx : integer := 0;
	SIGNAL clock_state: std_logic;
	type Adr_array_t is array (8 downto 0) of std_logic;
	SIGNAL Adr_array : Adr_array_t;
	SIGNAL Data_array : std_logic_vector(9 downto 0);
	
	SIGNAL clock_phase :integer Range 0 to 3;
	--SIGNAL Z_State : integer := 0;
	--SIGNAL Auslesen_State : integer := 0;
	--SIGNAL Init_State : integer := 0;
	--SIGNAL Write_State : integer := 0;
	
	

begin
	-- Temperatur ADRESSIERUNG
	Adr_array(0) <= '1';
	Adr_array(1) <= '0';
	Adr_array(2) <= '0';
	Adr_array(3) <= '1';
	Adr_array(4) <= '0';
	Adr_array(5) <= '1';
	Adr_array(6) <= '1';
--	Adr_array(7) <= '1';
--	Adr_array(8) <= '1';



	process (CLOCK_50)
		begin
		if (BUTTON = '0') then
			State <= Init_State;
--			i2c_clk <= '1';
			i2c_sda <= '1';
			counter_stp <= 0;
			stp_clk <= '0';
			counter <= 0;
			clock_state <= '1';
			clock_phase <= 0;
		ELsIF rising_edge(CLOCK_50) then
			counter <= counter +1;
			
			if (counter_stp = 5) then
				counter_stp <= 0;
				stp_clk <= not stp_clk;
			else
				counter_stp <= counter_stp + 1;
			end if;
			
			if( counter = CLOCK_FREQ-1) then  -- Teiler: 4
				counter <= 0;
				
				if (clock_phase = 1 or clock_phase = 3) then
					clock_state <=  not clock_state;
				end if;
				
				if (clock_phase = 3) then
					clock_phase <= 0;
				else
					clock_phase <= clock_phase + 1;
				end if;
			end if;

			
				if(   (counter = 100 and clock_state = '1' and (State = init_state or State = Data))   or   (counter = 700 and clock_state = '0' and (State /= init_state and State /= data)) )then
				Case State IS
					When Init_State =>
					if(clock_state = '1') then
						i2c_sda <= '0';
						State <= Addressing;
						idx <= 0;
					End if;
					When Addressing =>
--						if(clock_state = '1') then
							i2c_sda <= Adr_array(idx);
							
-- JK						if(idx = 8) then
							if(idx = 6) then
								idx <= 0;
								State <= readWrite;
								
							ELSE
								idx <= idx+1;
								
							END IF;
--						END IF;
				
					When readWrite =>
						i2c_sda <= '1';
						State <= ZState;
					
						
					When ZState =>
						
--						if(idx = 1 ) then
						i2c_sda <= 'Z';
						idx <= 0;
						State <= Acknow;
--						else 
--						idx <= idx+1;
--						end if;
						
					When Acknow =>
						IF(i2c_sda = '0') then
							State <= Data;
						End IF;
						
					When Data =>	
--					if(clock_state = '1') then		
						Data_array(idx)<=i2c_sda ;
						-- idx 8 oder 9?
						if (idx = 8) then
							state <= EndState;
							idx <= idx + 1;
						end if;
						
						
						if(idx = 7) then
--							idx <= 0;
							State <= Acknow2;
							i2c_sda <= '0';
							idx <= idx + 1;
						ELSE
							idx <= idx+1;							
						END IF;
--					END IF;

					When Acknow2 =>
						i2c_sda <= 'Z';
						State <= Data;
						
					When EndState =>
						if (idx = 15) then
							i2c_sda <= '0';
							state <= Processing;
							idx <= 0;
						else
							idx <= idx + 1;
						end if;
						
					When Processing =>
						i2c_sda <= '1';
						if (idx = 100) then
							state <= init_state;
							idx <= 0;
						else
							idx <= idx + 1;
						end if;
					
					End Case;
					
					End if;
		end if;
	
	end process;
	
	LEDG(9 downto 0) <= Data_array;
	HEX0_D <= "0000" & conv_std_logic_vector(clock_phase,2) & stp_clk;
	
	i2c_clk <= clock_state;
	

end arch;

--30 GND
--29 VCC
--D21 Scl
--D20 sda