-------------------------------------------------------------------------------
-- Title      : tb_i2c_config
-- Project    : 
-------------------------------------------------------------------------------
-- File       : tb_i2c_config.vhd
-- Author     : Hannu Ranta  
-- Company    : 
-- Created    : 2011-04-14
-- Last update: 2011/05/26
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Testbench for i2c config 
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-04-14  1.0      ranta5  Created
-------------------------------------------------------------------------------

-- Kaytettavat kirjastot
library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------
-- Empty entity
-------------------------------------------------------------------------------

entity tb_i2c_config is
end tb_i2c_config;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture testbench of tb_i2c_config is

  -- Number of parameters to expect
  constant n_params_c     : integer := 10;
  constant i2c_freq_c     : integer := 20000;
  constant ref_freq_c     : integer := 50000000;
  constant clock_period_c : time    := 20 ns;

  -- Every transmission consists several bytes and every byte contains given
  -- amount of bits. 
  constant n_bytes_c       : integer := 3;
  constant bit_count_max_c : integer := 8;

  -- Signals fed to the DUV
  signal clk   : std_logic := '0';      -- Remember that default values supported
  signal rst_n : std_logic := '0';      -- only in synthesis

  -- The DUV prototype
  component i2c_config
    generic (
      ref_clk_freq_g   :       integer;
      i2c_freq_g       :       integer;
      n_params_g       :       integer);
    port (
      clk              : in    std_logic;
      rst_n            : in    std_logic;
      sdat_inout       : inout std_logic;
      sclk_out         : out   std_logic;
      param_status_out : out   std_logic_vector(n_params_g-1 downto 0);
      finished_out     : out   std_logic
      );
  end component;

  -- Signals coming from the DUV
  signal sdat         : std_logic := 'Z';
  signal sclk         : std_logic;
  signal param_status : std_logic_vector(n_params_c-1 downto 0);
  signal finished     : std_logic;

  -- To hold the value that will be driven to sdat when sclk is high.
  signal sdat_r : std_logic;

  -- Counters for receiving bits and bytes
  signal bit_counter_r  : integer range 0 to bit_count_max_c;
  signal byte_counter_r : integer range 0 to n_bytes_c-1;
  signal data_counter_r : integer;      -- datalaskuri

  -- States for the FSM
  type states is (wait_start, read_byte, send_ack, wait_stop);
  signal curr_state_r : states;

  -- Previous values of the I2C signals for edge detection
  signal sdat_old_r : std_logic;
  signal sclk_old_r : std_logic;

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Itse lisatyt signaalit ja vakiot:

  constant data_count_c : integer := 10;  -- vastaanotettavan datan maara


  -- lahetetaan nailla hetkilla NACK
  constant send_NACK_one : integer := 3;
  constant nack_delay_c  : integer := 5;

  signal nack_done  : std_logic;        -- kun NACK on lahetetty
  signal nack_delay : std_logic;        -- lasketaan valiin jaanyt bitti 


  -- Vastaanotettavalle datalle taulukko
  type data_arr is array ((data_count_c - 1) downto 0)
    of std_logic_vector(((bit_count_max_c * n_bytes_c) - 1) downto 0);

  -- Vastaanotettavat arvot, ensin audiopiirin osoite, sitten rekisterin osoite
  -- viimeiset 8 bittia dataa.(Tarkistusta varten)
  constant data_signal : data_arr := ("001101000000000000011010", "001101000000001000011010",
                                      "001101000000010001111011", "001101000000011001111011",
                                      "001101000000100011111000", "001101000000101000000110",
                                      "001101000000110000000000", "001101000000111000000010",
                                      "001101000001000000000010", "001101000001001000000001");

  -- Rekisteri jonne seuraavana vuorossa oleva kolmen tavun joukko laitetaan
  signal send_register_r : std_logic_vector(((bit_count_max_c * n_bytes_c) - 1) downto 0);

  -- Rekisteri jonne tarkistuarvo laitetaan
  signal check_register_r : std_logic_vector((bit_count_max_c - 1) downto 0);

  -- Rekisteri jonne vastaanotettu tavu laitetaan
  signal byte_register_r : std_logic_vector((bit_count_max_c - 1) downto 0);

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------

begin  -- testbench

  clk   <= not clk after clock_period_c/2;
  rst_n <= '1'     after clock_period_c*4;

  -- Assign sdat_r when sclk is active, otherwise 'Z'.
  -- Note that sdat_r is usually 'Z'
  with sclk select
    sdat <=
    sdat_r when '1',
    'Z'    when others;


  -- Component instantiation
  i2c_config_1 : i2c_config
    generic map (
      ref_clk_freq_g   => ref_freq_c,
      i2c_freq_g       => i2c_freq_c,
      n_params_g       => n_params_c)
    port map (
      clk              => clk,
      rst_n            => rst_n,
      sdat_inout       => sdat,
      sclk_out         => sclk,
      param_status_out => param_status,
      finished_out     => finished);

  -----------------------------------------------------------------------------
  -- The main process that controls the behavior of the test bench
  fsm_proc : process (clk, rst_n)
  begin  -- process fsm_proc
    if rst_n = '0' then                 -- asynchronous reset (active low)

      curr_state_r <= wait_start;

      sdat_old_r <= '0';
      sclk_old_r <= '0';

      byte_counter_r <= 0;
      bit_counter_r  <= 0;
      data_counter_r <= 0;

      sdat_r <= 'Z';

      -- Nollataan tarkistukseen kaytettavat rekisterit
      byte_register_r  <= (others => '0');
      send_register_r  <= (others => '0');
      check_register_r <= (others => '0');

      -- Nollataan NACKiin liittyvat apusignaalit
      nack_done  <= '0';
      nack_delay <= '0';

    elsif clk'event and clk = '1' then  -- rising clock edge

      -- The previous values are required for the edge detection
      sclk_old_r <= sclk;
      sdat_old_r <= sdat;


      -- Falling edge detection for acknowledge control
      -- Must be done on the falling edge in order to be stable during
      -- the high period of sclk
      if sclk = '0' and sclk_old_r = '1' then

        -- If we are supposed to send ack
        if curr_state_r = send_ack then

          -- Jos ei olla lahetetty NACKia niin sdat_r = 0
          if data_counter_r /= send_NACK_one or nack_done = '1' then
            sdat_r <= '0';
          end if;

        else

          -- Otherwise, sdat is in high impedance state.
          sdat_r <= 'Z';

        end if;

      end if;


      -------------------------------------------------------------------------
      -- FSM
      case curr_state_r is

        -----------------------------------------------------------------------
        -- Wait for the start condition
        when wait_start =>

          -- While clk stays high, the sdat falls
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '1' and sdat = '0' then

            curr_state_r <= read_byte;

          end if;

          --------------------------------------------------------------------
          -- Wait for a byte to be read
        when read_byte =>

          sdat_r <= 'Z';

          -- Detect a rising edge
          if sclk = '1' and sclk_old_r = '0' then



            if bit_counter_r /= bit_count_max_c then

              -- Normally just receive a bit
              bit_counter_r <= bit_counter_r + 1;

            else

              -- When terminal count is reached, let's send the ack
              curr_state_r  <= send_ack;
              bit_counter_r <= 0;

            end if;  -- Bit counter terminal count

            if bit_counter_r /= bit_count_max_c then
              -- Kerataan sdat-signaalin bitit talteen
              byte_register_r((bit_count_max_c - bit_counter_r) - 1) <= sdat;

              -- Asetetaan oikeat arvot tarkistusrekistereihin
              send_register_r  <= data_signal((n_params_c - data_counter_r) - 1);
              check_register_r <= send_register_r((bit_count_max_c * (n_bytes_c - byte_counter_r) - 1)
                                                  downto ((bit_count_max_c * ((n_bytes_c - 1) - byte_counter_r))));
            else
              -- Nostetaan NACK ylos oikeana aikana 
              if (data_counter_r = send_NACK_one) and (nack_done = '0')
                and (byte_counter_r = n_bytes_c - 1) and (bit_counter_r = bit_count_max_c) then
                sdat_r         <= '1';
                nack_done      <= '1';
              end if;
            end if;


          end if;  -- sclk rising clock edge


          --------------------------------------------------------------------
          -- Send acknowledge
        when send_ack =>

          -- Detect a rising edge
          if sclk = '0' and sclk_old_r = '1' then

            if byte_counter_r /= n_bytes_c-1 then

              -- Transmission continues
              byte_counter_r <= byte_counter_r + 1;
              curr_state_r   <= read_byte;

            else
              -- Transmission is about to stop
              byte_counter_r <= 0;
              curr_state_r   <= wait_stop;

              -- Jos NACK on nostettuna ja datalaskuria kasvatettiin viimeksi
              -- niin pidetaan datalaskurin arvo samana, muuten kasvatetaan laskuria
              if nack_done = '1' and nack_delay = '0' then
                data_counter_r <= data_counter_r;
                nack_delay     <= '1';
              else
                data_counter_r <= data_counter_r + 1;
              end if;
            end if;


            -------------------------------------------------------------------
            -- Assertit vastaanotetun datan tarkastamiseen
            -------------------------------------------------------------------

            -- Tarkistetaan onko audiopiirin osoite vastaanotettu oikein
            if byte_counter_r = 0 then
              assert check_register_r = byte_register_r report "Audio codec address is incorrect" severity error;
            end if;

            -- Tarkistetaan onko rekisteriosoite vastaanotettu oikein
            if byte_counter_r = 1 then
              assert check_register_r = byte_register_r report "Register address is incorrect" severity error;
            end if;

            -- Tarkistetaan onko konfiguraatioarvot vastaanotettu oikein
            if byte_counter_r = 2 then
              assert check_register_r = byte_register_r report "Configuration Value is incorrect" severity error;
            end if;

            -------------------------------------------------------------------


          end if;

          ---------------------------------------------------------------------
          -- Wait for the stop condition
        when wait_stop =>
          sdat_r <= 'Z';
          -- Stop condition detection: sdat rises while sclk stays high
          if sclk = '1' and sclk_old_r = '1' and
            sdat_old_r = '0' and sdat = '1' then

            curr_state_r <= wait_start;

          end if;

      end case;

    end if;
  end process fsm_proc;

  -----------------------------------------------------------------------------
  -- Asserts for verification
  -----------------------------------------------------------------------------

  -- SDAT should never contain X:s.
  assert sdat /= 'X' report "Three state bus in state X" severity error;

  -- End of simulation, but not during the reset
  assert finished = '0' or rst_n = '0' report
    "Simulation done" severity failure;

end testbench;
