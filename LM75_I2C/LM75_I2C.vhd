LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_signed.ALL;
	
ENTITY SevenSegment IS
	PORT(
		-- Inputs
		HEX_INPUT : IN std_logic_vector(3 DOWNTO 0);
		-- Outputs
		HEX_OUTPUT : OUT std_logic_vector(6 DOWNTO 0)
	);
END SevenSegment;
	
	
ARCHITECTURE arch2 OF SevenSegment IS
BEGIN
	PROCESS(HEX_INPUT)
	BEGIN
		CASE HEX_INPUT is
		WHEN "0000" =>
			HEX_OUTPUT <= "1000000";
		WHEN "0001" =>
			HEX_OUTPUT <= "1111001";
		WHEN "0010" =>
			HEX_OUTPUT <= "0100100";
		WHEN "0011" =>
			HEX_OUTPUT <= "0110000";
		WHEN "0100" =>
			HEX_OUTPUT <= "0011001";
		WHEN "0101" =>
			HEX_OUTPUT <= "0010010";
		WHEN "0110" =>
			HEX_OUTPUT <= "0000010";
		WHEN "0111" =>
			HEX_OUTPUT <= "1111000";
		WHEN "1000" =>
			HEX_OUTPUT <= "0000000";
		WHEN "1001" =>
			HEX_OUTPUT <= "0011000";
		WHEN OTHERS =>
			HEX_OUTPUT <= "1111110";
		END CASE;
	END PROCESS;
END arch2;

LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_signed.ALL;

ENTITY LM75_I2C IS 
	PORT(	
		-- Inputs
		CLOCK_50 		: IN std_logic;
		BUTTON 			: IN std_logic;
		reset 			: IN std_logic;
		-- Outputs
		i2c_clk 			: OUT std_logic;
		HEX1_DEC_POINT : OUT std_logic := '0';
		HEX0_D 			: OUT std_logic_vector(6 DOWNTO 0);
		HEX1_D 			: OUT std_logic_vector(6 DOWNTO 0);
		HEX2_D 			: OUT std_logic_vector(6 DOWNTO 0);
		HEX3_D 			: OUT std_logic_vector(6 DOWNTO 0);
		LEDG 				: OUT std_logic_vector(9 DOWNTO 0);
		-- both
		i2c_sda 			: INOUT std_logic
	);
END LM75_I2C;
	
ARCHITECTURE arch OF LM75_I2C IS
	CONSTANT CLOCK_FREQ 				: integer := 400; 			-- Clock frequency factor
	SIGNAL counter 					: integer := 0; 				-- counter for Clock frequency
	TYPE State_type is  				(Init_State, Addressing,
											readWrite, Acknow, Acknow2,
											Acknow_Master, Acknow_Master2,
											Data, Data2, ENDState, StopState,
											StopState2, Processing); 	-- i2c states
	SIGNAL state 						: State_type; 					-- current State 
	SIGNAL idx 							: integer := 0; 				-- index used for looping and Adr+Data Array Fields
	SIGNAL clock_state				: std_logic; 					-- state of the clock --> High / Low
	TYPE Adr_array_t IS ARRAY (6 DOWNTO 0) OF std_logic; 		-- 7 Bit Array type of std_logic
	SIGNAL adr_array 					: Adr_array_t; 				-- Adress Array
	SIGNAL data_array 				: std_logic_vector(0 TO 15); -- 16 Bit Data Array
	SIGNAL processing_data 			: integer; 						-- converted int of Data
	SIGNAL comma,c 					: integer := 0; 				-- new comma, old comma
	SIGNAL ones,o 						: integer := 0; 				-- new ones, old ones
	SIGNAL tens,t 						: integer := 0; 				-- new tens, old tens
	SIGNAL hundreds,h 				: integer := 0; 				-- new hundreds, old hundreds
	SIGNAL processing_data_half 	: integer := 0; 				-- the real temperature in degrees celsius
	SIGNAL clock_phase 				:integer RANGE 0 TO 3; 		-- current phase of the clock | 0/risingEdge/1/fallingEdge
	
	COMPONENT SevenSegment IS
		PORT(
			HEX_INPUT : IN std_logic_vector(3 DOWNTO 0);
			HEX_OUTPUT : OUT std_logic_vector(6 DOWNTO 0)
		);
	END COMPONENT;

BEGIN
	Adr_array(6 DOWNTO 0) <= "1101001"; -- temperature addressing
	PROCESS (CLOCK_50)
	VARIABLE cp : integer RANGE 0 TO 3;
		BEGIN
		IF (BUTTON = '0') THEN -- Reset / (Hold) -> lets you hold the temp value
			State <= Init_State;
			i2c_sda <= '1';
			counter <= 0;
			clock_state <= '1';
			clock_phase <= 0;
		ELSIF rising_edge(CLOCK_50) THEN
			counter <= counter +1;
			IF( counter = CLOCK_FREQ) THEN  -- divider: 4
				counter <= 0;
				IF (clock_phase = 1 or clock_phase = 3) THEN -- high/low
					clock_state <=  not clock_state;
				END IF;
				IF (clock_phase = 3) THEN -- low
					cp := 0;
				ELSE
					cp := clock_phase + 1;
				END IF;
				clock_phase <= cp;
				CASE state IS
					WHEN Init_State => -- set sda to 0 and i2c_clk will be set to '1' --> Start condition
						IF (cp = 1) THEN 
							i2c_sda <= '0';
							state <= Addressing;
							idx <= 0;
						END IF;
					WHEN Addressing => -- sENDs the adr_data over sda to temp.sensor --> requests temp. value
						IF (cp = 3) THEN 
							IF (Adr_array(idx) = '1') THEN 
								i2c_sda <= 'Z';
							ELSE 
								i2c_sda <= '0';
							END IF;
						END IF;
						IF (cp = 0) THEN
							idx <= idx + 1;
							IF (idx = 6) THEN
								state <=  readWrite;
								idx <= 0;
							END IF;
						END IF;
					WHEN readWrite => 		-- Set value IF you want to read or write
						IF (cp = 3) THEN
							i2c_sda <= 'Z';
						END IF;
						IF (cp = 0) THEN
							state <= Acknow;
						END IF;
					WHEN Acknow => 			-- Set value IF you want to read or write | guarantees 'Z' at right time 
						IF (cp = 3) THEN
							i2c_sda <= 'Z';
						END IF;
						IF (cp = 0) THEN
							state <=  Acknow2;
						END IF;
					WHEN Acknow2 => 			-- at cp=high and sda=0 --> ready to read data
						IF (cp = 1 and i2c_sda = '0') THEN
							state <= Data;
							idx <= 0;
						END IF;				
					WHEN Data => 				-- reads the temp value that the sensor sENDs at the right time
						IF (cp = 1) THEN
							data_array(idx) <= i2c_sda; -- reads data shortly after cp=high
							idx <= idx + 1;
							IF (idx = 7) THEN
								state <= Acknow_Master;
							END IF;
						END IF;
					WHEN Acknow_Master => 	-- IF cp=low then set sda=low
						IF (cp = 3) THEN
							i2c_sda <= '0';
							state <= Acknow_Master2;
						END IF;
					WHEN Acknow_Master2 =>	-- then set sda to 'Z'
						IF (cp = 3) THEN
							i2c_sda <= 'Z';
							State <= Data2;
						END IF;
					WHEN Data2 => 				-- read data2 at cp=high
						IF (cp = 1) THEN
							data_array(idx) <= i2c_sda;
							idx <= idx + 1;
							IF (idx = 15) THEN
								state <= ENDState;
							END IF;
						END IF;
					WHEN ENDState => 			-- END reading data --> set sda to 'Z'
						IF (cp = 3) THEN
							i2c_sda <= 'Z';
							state <= StopState;
						END IF;
					WHEN StopState => 		-- stop condition --> WHEN cp=low set sda=low
						IF (cp = 3) then
							i2c_sda <= '0';
							state <= StopState2;
							idx <= 0;
						END IF;
					WHEN StopState2 => 		-- WHEN cp=high set sda to 'Z' --> for 3000 cycles (wait some time for next statemachine cycle)
						IF (cp = 1) then
							i2c_sda <= 'Z';
							IF (idx = 3000) then
								state <= Processing;
								idx <= 0;
							else 
								idx <= idx + 1;
							END IF;
						END IF;
					WHEN Processing => 		-- processes the temperature data we read
						processing_data <= conv_integer(unsigned(data_array(0 to 8)));
						c <= comma;
						o <= ones;
						t <= tens;
						h <= hundreds;
						state <= init_state;
					WHEN OTHERS => 			-- need to define WHEN OTHERS
				END CASE;
			END IF;
		END IF;
	END PROCESS;
	processing_data_half <= ((processing_data * 10)/2); 	-- integer rep. data of temp. sensor * 10 (to switch to integer range) and devide by 2 | 205 --> 20.5 C 
	hundreds <= ((processing_data_half / 1000) mod 10); 	-- processing hundreds value
	tens <= ((processing_data_half / 100) mod 10); 			-- processing tens value
	ones <= ((processing_data_half / 10) mod 10); 			-- processing ones value
	comma <= processing_data_half mod 10; 						-- processing comma value
	
	map0: SevenSegment PORT MAP(conv_std_logic_vector(c,4), HEX0_D); -- set HEX0 Segment
	map1: SevenSegment PORT MAP(conv_std_logic_vector(o,4), HEX1_D); -- set HEX1 Segment
	map2: SevenSegment PORT MAP(conv_std_logic_vector(t,4), HEX2_D); -- set HEX2 Segment
	map3: SevenSegment PORT MAP(conv_std_logic_vector(h,4), HEX3_D); -- set HEX3 Segment

	LEDG(9 DOWNTO 0) <= '0' & Data_array(0) & Data_array(1) & Data_array(2) & Data_array(3) & Data_array(4) & Data_array(5) & Data_array(6) & Data_array(7) & Data_array(8); -- Led representation of Data_array
	i2c_clk <= clock_state;
END arch;