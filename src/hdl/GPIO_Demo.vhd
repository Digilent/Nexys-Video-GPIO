----------------------------------------------------------------------------
--	GPIO_Demo.vhd -- Nexys Video GPIO/UART Demonstration Project
----------------------------------------------------------------------------
-- Author:  Samuel Lowe adapted from..
--          Marshall Wingerson Adapted from Sam Bobrowicz
--          Copyright 2015 Digilent, Inc.
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
--	The GPIO/UART Demo project demonstrates a simple usage of the Nexys4DDR's 
--  GPIO and UART. The behavior is as follows:
--
--	      *The 8 User LEDs are tied to the 8 User Switches.
--       *An introduction message is sent across the UART when the device
--        is finished being configured, and after the center User button
--        is pressed.
--       *A message is sent over UART whenever BTNU, BTNL, BTND, or BTNR is
--        pressed.
--        
--	All UART communication can be captured by attaching the UART port to a
-- computer running a Terminal program with 9600 Baud Rate, 8 data bits, no 
-- parity, and 1 stop bit.																
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- Revision History:
--  08/08/2011(SamB): Created using Xilinx Tools 13.2
--  08/27/2013(MarshallW): Modified for the Nexys4 with Xilinx ISE 14.4\
--  		--added RGB and microphone
--  12/10/2014(SamB): Ported to Nexys4DDR and updated to Vivado 2014.4
--  12/10/2014(SamL): Ported to Nexys Video and updated to Vivado 2015.1
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--The IEEE.std_logic_unsigned contains definitions that allow 
--std_logic_vector types to be used with the + operator to instantiate a 
--counter.
use IEEE.std_logic_unsigned.all;

entity GPIO_demo is
    Port ( SW 			        : in   STD_LOGIC_VECTOR (7 downto 0);
           RSTN                 : in   STD_LOGIC;
           BTN 			        : in   STD_LOGIC_VECTOR (4 downto 0);
           CLK 			        : in   STD_LOGIC;
           LED 			        : out  STD_LOGIC_VECTOR (7 downto 0);
           UART_TXD 	        : out  STD_LOGIC;
           oled_dc 			    : out  STD_LOGIC;
           oled_res 			: out  STD_LOGIC;
           oled_sclk 			: out  STD_LOGIC;
           oled_sdin 			: out  STD_LOGIC;
           oled_vbat 			: out  STD_LOGIC;
           oled_vdd 			: out  STD_LOGIC       
          );
end GPIO_demo;

architecture Behavioral of GPIO_demo is

component UART_TX_CTRL
Port(
	SEND : in std_logic;
	DATA : in std_logic_vector(7 downto 0);
	CLK : in std_logic;
	READY : out std_logic;
	UART_TX : out std_logic
	);
end component;

component debouncer
Generic(
        DEBNC_CLOCKS : integer;
        PORT_WIDTH : integer);
Port(
		SIGNAL_I : in std_logic_vector(5 downto 0);
		CLK_I : in std_logic;          
		SIGNAL_O : out std_logic_vector(5 downto 0)
		);
end component;

component OLED_master
Port(
    clk : in std_logic;
    rstn : in std_logic;
    oled_sdin : out std_logic;
    oled_sclk : out std_logic;
    oled_dc   : out std_logic;
    oled_res  : out std_logic;
    oled_vbat : out std_logic;
    oled_vdd  : out std_logic
	);
end component;



--The type definition for the UART state machine type. Here is a description of what
--occurs during each state:
-- RST_REG     -- Do Nothing. This state is entered after configuration or a user reset.
--                The state is set to LD_INIT_STR.
-- LD_INIT_STR -- The Welcome String is loaded into the sendStr variable and the strIndex
--                variable is set to zero. The welcome string length is stored in the StrEnd
--                variable. The state is set to SEND_CHAR.
-- SEND_CHAR   -- uartSend is set high for a single clock cycle, signaling the character
--                data at sendStr(strIndex) to be registered by the UART_TX_CTRL at the next
--                cycle. Also, strIndex is incremented (behaves as if it were post 
--                incremented after reading the sendStr data). The state is set to RDY_LOW.
-- RDY_LOW     -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go low, 
--                indicating a send operation has begun. State is set to WAIT_RDY.
-- WAIT_RDY    -- Do nothing. Wait for the READY signal from the UART_TX_CTRL to go high, 
--                indicating a send operation has finished. If READY is high and strEnd = 
--                StrIndex then state is set to WAIT_BTN, else if READY is high and strEnd /=
--                StrIndex then state is set to SEND_CHAR.
-- WAIT_BTN    -- Do nothing. Wait for a button press on BTNU, BTNL, BTND, or BTNR. If a 
--                button press is detected, set the state to LD_BTN_STR.
-- LD_BTN_STR  -- The Button String is loaded into the sendStr variable and the strIndex
--                variable is set to zero. The button string length is stored in the StrEnd
--                variable. The state is set to SEND_CHAR.
type UART_STATE_TYPE is (RST_REG, LD_INIT_STR, SEND_CHAR, RDY_LOW, WAIT_RDY, WAIT_BTN, LD_BTN_STR);

--The CHAR_ARRAY type is a variable length array of 8 bit std_logic_vectors. 
--Each std_logic_vector contains an ASCII value and represents a character in
--a string. The character at index 0 is meant to represent the first
--character of the string, the character at index 1 is meant to represent the
--second character of the string, and so on.
type CHAR_ARRAY is array (integer range<>) of std_logic_vector(7 downto 0);

constant TMR_CNTR_MAX : std_logic_vector(26 downto 0) := "101111101011110000100000000"; --100,000,000 = clk cycles per second
constant TMR_VAL_MAX : std_logic_vector(3 downto 0) := "1001"; --9

constant RESET_CNTR_MAX : std_logic_vector(17 downto 0) := "110000110101000000";-- 100,000,000 * 0.002 = 200,000 = clk cycles per 2 ms

constant MAX_STR_LEN : integer := 31;

constant WELCOME_STR_LEN : natural := 31;
constant BTN_STR_LEN : natural := 24;

--Welcome string definition. Note that the values stored at each index
--are the ASCII values of the indicated character.
constant WELCOME_STR : CHAR_ARRAY(0 to 30) := 				 (X"0A",  --\n
															  X"0D",  --\r
															  X"4E",  --N
															  X"45",  --E
															  X"58",  --X
															  X"59",  --Y
															  X"53",  --S 
															  X"20",  --
															  X"56",  --V
															  X"49",  --I
															  X"44",  --D
															  X"45",  --E
															  X"4F",  --0
															  X"20",  --
															  X"55",  --U
															  X"41",  --A
															  X"52",  --R 
															  X"54",  --T
															  X"20",  --
															  X"44",  --D
															  X"45",  --E
															  X"4D",  --M
															  X"4F",  --O 
															  X"21",  --! 
															  X"20",  -- 
															  X"20",  -- 
															  X"20",  -- 
															  X"20",  -- 
															  X"0A",  --\n
															  X"0A",  --\n
															  X"0D"); --\r
															  
--Button press string definition.
constant BTN_STR : CHAR_ARRAY(0 to 23) :=     				 (X"42",  --B
															  X"75",  --u
															  X"74",  --t
															  X"74",  --t
															  X"6F",  --o
															  X"6E",  --n
															  X"20",  -- 
															  X"70",  --p
															  X"72",  --r
															  X"65",  --e
															  X"73",  --s
															  X"73",  --s
															  X"20",  --
															  X"64",  --d
															  X"65",  --e
															  X"74",  --t
															  X"65",  --e
															  X"63",  --c
															  X"74",  --t
															  X"65",  --e
															  X"64",  --d
															  X"21",  --!
															  X"0A",  --\n
															  X"0D"); --\r

--This is used to determine when the 7-segment display should be
--incremented
signal tmrCntr : std_logic_vector(26 downto 0) := (others => '0');



--This counter keeps track of which number is currently being displayed
--on the 7-segment.
signal tmrVal : std_logic_vector(3 downto 0) := (others => '0');

--Contains the current string being sent over uart.
signal sendStr : CHAR_ARRAY(0 to (MAX_STR_LEN - 1));

--Contains the length of the current string being sent over uart.
signal strEnd : natural;

--Contains the index of the next character to be sent over uart
--within the sendStr variable.
signal strIndex : natural;

--Used to determine when a button press has occured
signal btnReg : std_logic_vector (4 downto 0) := "00000";
signal btnDetect : std_logic;

--UART_TX_CTRL control signals
signal uartRdy : std_logic;
signal uartSend : std_logic := '0';
signal uartData : std_logic_vector (7 downto 0):= "00000000";
signal uartTX : std_logic;

--Current uart state signal
signal uartState : UART_STATE_TYPE := RST_REG;

--Debounced btn signals used to prevent single button presses
--from being interpreted as multiple button presses.
signal btnDeBnc : std_logic_vector(5 downto 0);

signal clk_cntr_reg : std_logic_vector (4 downto 0) := (others=>'0'); 

--signal pwm_val_reg : std_logic := '0';

--this counter counts the amount of time paused in the UART reset state
signal reset_cntr : std_logic_vector (17 downto 0) := (others=>'0');

begin

----------------------------------------------------------
------                LED Control                  -------
----------------------------------------------------------

-- Tie the LEDs straight to the switches

	LED <= SW;
			 			 

----------------------------------------------------------
------              Button Control                 -------
----------------------------------------------------------
--Buttons are debounced and their rising edges are detected
--to trigger UART messages


--Debounces btn signals 
Inst_btn_debounce: debouncer 
    generic map(
        DEBNC_CLOCKS => (2**16),
        PORT_WIDTH => 6)
    port map(
		SIGNAL_I => RSTN & BTN,
		CLK_I => CLK,
		SIGNAL_O => btnDeBnc
	);

--Registers the debounced button signals, for edge detection.
btn_reg_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		btnReg <= btnDeBnc(4 downto 0);
	end if;
end process;

--btnDetect goes high for a single clock cycle when a btn press is
--detected. This triggers a UART message to begin being sent.
btnDetect <= '1' when ((btnReg(0)='0' and btnDeBnc(0)='1') or
								(btnReg(1)='0' and btnDeBnc(1)='1') or
								(btnReg(2)='0' and btnDeBnc(2)='1') or
								(btnReg(3)='0' and btnDeBnc(3)='1') or
								(btnReg(4)='0' and btnDeBnc(4)='1') ) else
				  '0';
				  



----------------------------------------------------------
------              UART Control                   -------
----------------------------------------------------------
--Messages are sent on reset and when a button is pressed.

--This counter holds the UART state machine in reset for ~2 milliseconds. This
--will complete transmission of any byte that may have been initiated during 
--FPGA configuration due to the UART_TX line being pulled low, preventing a 
--frame shift error from occuring during the first message.
process(CLK)
begin
  if (rising_edge(CLK)) then
    if ((reset_cntr = RESET_CNTR_MAX) or (uartState /= RST_REG)) then
      reset_cntr <= (others=>'0');
    else
      reset_cntr <= reset_cntr + 1;
    end if;
  end if;
end process;

--Next Uart state logic (states described above)
next_uartState_process : process (CLK)
begin
	if (rising_edge(CLK)) then
			
			case uartState is 
			when RST_REG =>
        if (reset_cntr = RESET_CNTR_MAX) then
          uartState <= LD_INIT_STR;
        end if;
			when LD_INIT_STR =>
				uartState <= SEND_CHAR;
			when SEND_CHAR =>
				uartState <= RDY_LOW;
			when RDY_LOW =>
				uartState <= WAIT_RDY;
			when WAIT_RDY =>
				if (uartRdy = '1') then
					if (strEnd = strIndex) then
						uartState <= WAIT_BTN;
					else
						uartState <= SEND_CHAR;
					end if;
				end if;
			when WAIT_BTN =>
				if (btnDetect = '1') then
					uartState <= LD_BTN_STR;
				end if;
			when LD_BTN_STR =>
				uartState <= SEND_CHAR;
			when others=> --should never be reached
				uartState <= RST_REG;
			end case;
		
	end if;
end process;

--Loads the sendStr and strEnd signals when a LD state is
--is reached.
string_load_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (uartState = LD_INIT_STR) then
			sendStr <= WELCOME_STR;
			strEnd <= WELCOME_STR_LEN;
		elsif (uartState = LD_BTN_STR) then
			sendStr(0 to 23) <= BTN_STR;
			strEnd <= BTN_STR_LEN;
		end if;
	end if;
end process;

--Conrols the strIndex signal so that it contains the index
--of the next character that needs to be sent over uart
char_count_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (uartState = LD_INIT_STR or uartState = LD_BTN_STR) then
			strIndex <= 0;
		elsif (uartState = SEND_CHAR) then
			strIndex <= strIndex + 1;
		end if;
	end if;
end process;

--Controls the UART_TX_CTRL signals
char_load_process : process (CLK)
begin
	if (rising_edge(CLK)) then
		if (uartState = SEND_CHAR) then
			uartSend <= '1';
			uartData <= sendStr(strIndex);
		else
			uartSend <= '0';
		end if;
	end if;
end process;

--Component used to send a byte of data over a UART line.
Inst_UART_TX_CTRL: UART_TX_CTRL port map( 
		SEND => uartSend,
		DATA => uartData,
		CLK => CLK,
		READY => uartRdy,
		UART_TX => uartTX 
	);

UART_TXD <= uartTX;


----------------------------------------------------------
------              OLED Control                   -------
----------------------------------------------------------

INST_OLED: OLED_master port map (
    clk => CLK,
    rstn => btnDeBnc(5),
    oled_sdin => oled_sdin,
    oled_sclk => oled_sclk,
    oled_dc   => oled_dc,
    oled_res  => oled_res,
    oled_vbat => oled_vbat,
    oled_vdd  => oled_vdd
);
end Behavioral;
