LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_signed.ALL;
	
ENTITY SevenSegment IS
	PORT(
		-- Inputs
		HEX_INPUT  : IN std_logic_vector(7 DOWNTO 0);
		-- Outputs
		HEX_OUTPUT : OUT std_logic_vector(6 DOWNTO 0)
	);
END SevenSegment;
	
	
ARCHITECTURE arch2 OF SevenSegment IS
BEGIN
	PROCESS(HEX_INPUT)
	BEGIN
		CASE HEX_INPUT IS
		WHEN "00010010" => -- Inverse ASCII 'H'
			HEX_OUTPUT <= "0001001";
		WHEN "10010010" => -- Inverse ASCII 'I'
			HEX_OUTPUT <= "1001111";
		WHEN "11110010" => -- Inverse ASCII 'O'
			HEX_OUTPUT <= "1000000";
		WHEN OTHERS =>
		END CASE;
	END PROCESS;
END arch2;

LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_signed.ALL;


ENTITY UART IS 
	PORT(	
		-- Inputs
		CLOCK_50  : IN std_logic;
		UART1_RX  : IN std_logic;
		-- Outputs
		UART2_TX  : OUT std_logic;
		HEX0_D	 : OUT std_logic_vector(6 downto 0) := "1111111";
		LEDG 		 : OUT std_logic_vector(9 downto 0) := "0000000000"
	);
END UART;

ARCHITECTURE arch OF UART IS
	CONSTANT LED_IDLE_STATE 	: std_logic_vector(9 downto 0) := "1000000000";
	CONSTANT LED_START_STATE 	: std_logic_vector(9 downto 0) := "0100000000";
	CONSTANT LED_DATA_STATE 	: std_logic_vector(9 downto 0) := "0010000000";
	CONSTANT LED_PARITY_STATE 	: std_logic_vector(9 downto 0) := "0001000000";
	CONSTANT LED_STOP_STATE 	: std_logic_vector(9 downto 0) := "0000100000";
	-- In this Example:
	-- *** UART1 is just receiving 
	-- *** UART2 is just sending 
	CONSTANT UART_BITRATE	 	: integer := 2000000; 			 -- Bitrate = 25 bit/s --> DataThroughPut = 16 bit/s
	CONSTANT UART2_TX_END_IDX 	: integer := 47;
	 -- 4x ==> (1)[StartBit](8)[DataBits](1)[ParityBit](1)[StopBit](1)[SleepBits]
	CONSTANT UART2_TX_MSG 		: std_logic_vector(0 to UART2_TX_END_IDX) 
										:= "000010010011010010010111000010010011011110010111";
	TYPE State_type is         (IDLE_STATE, START_STATE,
							          DATA_STATE, PARITY_STATE,
							          STOP_STATE); 						 -- UART States
	SIGNAL UART1_STATE 			: State_type 	:= START_STATE; -- Current UART State 
	SIGNAL UART_FREQ_CNT 		: integer 		:= 0; 			 -- Counter for Frequency
	SIGNAL UART1_DATA_CNT 		: integer 		:= 0; 			 -- UART1 Counter for Data catching
	SIGNAL UART2_SEND_CNT 		: integer 		:= 0; 			 -- Counter for Sending Signal
	SIGNAL PARITY 					: std_logic 	:= '0'; 			 -- Checks Data for parity
	SIGNAL UART1_REC 				: std_logic_vector(0 to 7);	 -- Checks the RX for Data
	SIGNAL UART1_MSG 				: std_logic_vector(0 to 7); 	 -- Received Data 
	
	COMPONENT SevenSegment is
		PORT(
			HEX_INPUT 	: in std_logic_vector(7 downto 0);
			HEX_OUTPUT 	: out std_logic_vector(6 downto 0)
		);
	END COMPONENT;

BEGIN
	PROCESS (CLOCK_50)
		BEGIN
		IF rising_edge(CLOCK_50) THEN
			UART_FREQ_CNT <= UART_FREQ_CNT +1;
			IF (UART_FREQ_CNT >= UART_BITRATE) THEN
				UART_FREQ_CNT <= 0;
				UART2_TX <= UART2_TX_MSG(UART2_SEND_CNT);
				UART2_SEND_CNT <= UART2_SEND_CNT + 1;
				IF (UART2_SEND_CNT >= UART2_TX_END_IDX) THEN
					UART2_SEND_CNT <= 0;
				END IF;
				CASE UART1_STATE IS
					WHEN STOP_STATE => 	-- Checks for the Stop Bit, that ends the Frame
						LEDG <= LED_STOP_STATE;
						IF (UART1_RX = '1') THEN 
							UART1_STATE <= IDLE_STATE;
							UART1_MSG <= UART1_REC;
						END IF;	
					WHEN PARITY_STATE => -- Checks for the Parity Bit
						LEDG <= LED_PARITY_STATE;
						IF (UART1_RX = PARITY) THEN 
							UART1_STATE <= STOP_STATE;
							PARITY <= '0';
						END IF;
					WHEN DATA_STATE => 	-- Catches the "pure" Data (here inversed ASCII Character)
						LEDG <= LED_DATA_STATE;
						UART1_REC(UART1_DATA_CNT) <= UART1_RX;
						UART1_DATA_CNT <= UART1_DATA_CNT + 1;
						IF (UART1_DATA_CNT >= 7) THEN
							UART1_STATE <= PARITY_STATE;
							UART1_DATA_CNT <= 0;
						END IF;	
						IF (UART1_RX = '1') THEN
							PARITY <= NOT PARITY;
						END IF;
					WHEN START_STATE => 	-- Checks for the Start Condition
						LEDG <= LED_START_STATE;
						IF (UART1_RX = '0') THEN 
							UART1_STATE <= DATA_STATE;
						END IF;						
					WHEN IDLE_STATE => 	-- Default State
						LEDG <= LED_IDLE_STATE;
						IF (UART1_RX = '1') THEN 
							UART1_STATE <= START_STATE;
						END IF;		
					WHEN OTHERS => 
				END CASE;
			END IF;
		END IF;
	END PROCESS;
	map0: SevenSegment PORT MAP(UART1_MSG, HEX0_D);
END arch;
