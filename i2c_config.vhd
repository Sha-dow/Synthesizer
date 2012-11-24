-------------------------------------------------------------------------------
-- Title      : I2C config
-- Project    : 
-------------------------------------------------------------------------------
-- File       : i2c_config.vhd
-- Author     : Hannu Ranta  
-- Company    : 
-- Created    : 2011-04-14
-- Last update: 2011/05/24
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: State Machine to configure
--                    Wolfson audio codec via i2c bus
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-04-14  1.0      hannu   Created
-------------------------------------------------------------------------------

-- Esitellaan kirjastot
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- Entity
-------------------------------------------------------------------------------
entity i2c_config is

  generic (
    ref_clk_freq_g : integer := 50000000;  -- clk signaalin taajuus (Hz)
    i2c_freq_g     : integer := 20000;     -- i2c vaylan taajuus (Hz)
    n_params_g     : integer := 10);       -- konfiguraatioparametrien maara

  port (
    clk              : in    std_logic;  -- kello
    rst_n            : in    std_logic;  -- reset
    sdat_inout       : inout std_logic;  -- sdat_inout signaali
    sclk_out         : out   std_logic;  -- kello ulos
    param_status_out : out   std_logic_vector((n_params_g - 1) downto 0);  -- parametrit ulos
    finished_out     : out   std_logic);  -- nostetaan kun valmista

end i2c_config;

-------------------------------------------------------------------------------
-- Arkkitehtuurin maarittely alkaa
-------------------------------------------------------------------------------
architecture fsm of i2c_config is

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Signaalit:

  signal clk_counter : integer;         -- laskuri sclk:lle

  type states is (init, wait_start, start, send_data, wait_ack, wait_stop, stop, finish);  -- tilat
  signal curr_state_r : states;         -- seuraava tila
  signal next_state   : states;         -- seuraava tila

  signal bit_counter  : integer;        -- laskuri bittien lahetykseen
  signal byte_counter : integer;        -- laskuri tavujen lähetykseen
  signal data_counter : integer;        -- laskuri lahetyskertojen mittaukseen
  signal stop_start_delay_counter : integer;  -- laskuri stop ja start tilan viiveille

  signal stop_done : std_logic;         -- kun stop on valmis
  signal sclk_gen_signal : std_logic;   -- signaali kellon ganerointiin

  signal sdat_internal : std_logic;     -- sisainen signaali sdatille
  
  signal internal_param_status : std_logic_vector((n_params_g - 1) downto 0);
                                        -- sisainen signaali statusledeille
  
  signal start_done : std_logic;        -- onko datan lahetys aloitettu
  signal ack_done   : std_logic;        -- onko kuittausvaihe suoritettu

  signal nack_received : std_logic;     -- Jos saadaan NACK kuittaus niin nostetaan
  signal stop_status   : std_logic;     -- Jos ollaan menossa stoppiin
                                   
  signal wait_ready : std_logic;        -- kun odotus on valmis
  signal wait_counter : integer;        -- laskuri waitille

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Vakiot:                                                               
  constant bit_count_c  : integer := 8;   -- bittien maara/lahetys          
  constant byte_cout_c  : integer := 3;   -- tavujen maara              
  constant data_count_c : integer := 10;  -- lahetyskertojen maara        
  constant stop_delay_c : integer := 50;  -- stoptilan viive
  constant start_delay_c : integer := 625;  -- start tilan viive
  constant wait_stop_c : integer := 2000;  -- stopin viive
  constant wait_start_c : integer := 3000;  -- startin viive
  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  
  -- Taulukko lahetettavalle datalle
  type data_arr is array ((data_count_c - 1) downto 0)
    of std_logic_vector(((bit_count_c * byte_cout_c) - 1) downto 0);

  -- Lahetettavat arvot, ensin audiopiirin osoite, sitten rekisterin osoite
  -- viimeiset 8 bittia dataa.
  constant data_signal : data_arr := ("001101000000000000011010", "001101000000001000011010",
                                      "001101000000010001111011", "001101000000011001111011",
                                      "001101000000100011111000", "001101000000101000000110",
                                      "001101000000110000000000", "001101000000111000000010",
                                      "001101000001000000000010", "001101000001001000000001");

  -- rekisteri jonne seuraavana lahetettavat 3 tavua talletetaan
  signal send_register_r : std_logic_vector(((bit_count_c * byte_cout_c) - 1) downto 0);
  -- rekisteri jonne talletetaan seuraava lahetettava tavu
  signal byte_register_r : std_logic_vector((bit_count_c - 1) downto 0);
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
  
begin  -- fsm

  -- purpose: generoidaan sclk-signaali
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: sclk_out
  sclk_gen : process (clk, rst_n)
  begin  -- process sclk_gen
    if rst_n = '0' then                 -- asynchronous reset (active low)

      -- sclk_gen_signal resetissa ykkoseksi
      -- ja laskuri nollaan
      sclk_gen_signal <= '1';
      clk_counter     <= 1;

    elsif clk'event and clk = '1' then  -- rising clock edge

      -- Jos laskuri on saavuttanut puolet jaksonajasta niin
      -- invertoidaan sisaisen kellosignaalin arvo
      -- ja nollataan laskuri
      if clk_counter = ((ref_clk_freq_g / i2c_freq_g) / 2) then
        if curr_state_r = send_data or curr_state_r = wait_ack or curr_state_r = wait_stop then
          sclk_gen_signal <= not sclk_gen_signal;  
        end if;
        clk_counter     <= 1;

      -- Muussa tapauksessa kasvatetaan laskuria
      else
        clk_counter     <= clk_counter + 1;
      end if;

    end if;

  end process sclk_gen;

  -- Prosessin jalkeen sijoitetaan sisainen kellosignaali ulostuloon
  sclk_out <= sclk_gen_signal;

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------

  -- purpose: tilarekisterin seuraavan tilan maaraava prosessi
  -- type   : combinational
  -- inputs : curr_state_r
  -- outputs: next_state
  comb_ns : process (curr_state_r, rst_n, data_counter, start_done, bit_counter, ack_done,
                     stop_status, stop_done, wait_ready, sclk_gen_signal, clk_counter)

  begin  -- process comb_ns

    case curr_state_r is

      -------------------------------------------------------------------------
      -- Init
      -------------------------------------------------------------------------
      when init =>

        -- Jos reset on ylhaalla siirrytaan Start-tilaan
        -- muuten pysytaan Init- tilassa
        if rst_n = '1' then
          next_state <= start;
        else
          next_state <= init;
        end if;


        -------------------------------------------------------------------------
        -- Wait_Start
        -------------------------------------------------------------------------
      when wait_start =>

        -- Jos start_done signaali on ylhaalla on start suoritettu onnistuneesti
        -- ja voidaan siirtya lahettamaan dataa.
        -- Muussa tapauksessa jatketaan start tilassa
        if wait_ready = '1'  then
          next_state <= start;
        else
          next_state <= wait_start;
        end if;

        
        -------------------------------------------------------------------------
        -- Start
        -------------------------------------------------------------------------
      when start =>

        -- Jos start_done signaali on ylhaalla on start suoritettu onnistuneesti
        -- ja voidaan siirtya lahettamaan dataa.
        -- Muussa tapauksessa jatketaan start tilassa
        if start_done = '1' then
          next_state <= send_data;
        else
          next_state <= start;
        end if;

        -------------------------------------------------------------------------
        -- Send_data
        -------------------------------------------------------------------------
      when send_data =>

        -- jos bittilaskuri saavuttaa maksimiarvon on kaikki bitit lahetetty ja
        -- voidaan siirtya kuittauksen kuuntelutilaan, muussa tapauksessa
        -- pysytaan datanlahetystilassa
        if bit_counter = bit_count_c and sclk_gen_signal = '0'
           and clk_counter = ((ref_clk_freq_g / i2c_freq_g) / 4) then
          
          next_state <= wait_ack;
        else
          next_state <= send_data;
        end if;

        -------------------------------------------------------------------------
        -- Wait_ack
        -------------------------------------------------------------------------
      when wait_ack =>

        -- Jos kuittaus on saatu onnistuneesti eli ack_done signaali on
        -- ylhaalla siirrytaan wait_stop tilaan mikali stop_status signaali on
        -- ylhaalla eli 3 tavua on lahetetty, muussa tapauksessa siirrytaan
        -- suoraan datanlahetystilaan. Jos ack_done signaali on alhaalla
        -- pysytaan wait_ack tilassa.
        if ack_done = '1' then
          if stop_status = '1' then
            next_state <= wait_stop;
          else
            next_state <= send_data;
          end if;
        else
          next_state   <= wait_ack;
        end if;



        -------------------------------------------------------------------------
        -- Wait_Stop
        -------------------------------------------------------------------------
      when wait_stop =>

        -- Odotetaan SDAT-signaalin vapautumista ennen stop-tilaan
        -- menoa. Kun odotus on valmis nostetaan Wait-ready signaali ylos
        -- ja siirrytaan stop-tilaan
        if wait_ready = '1' then
          
          next_state <= stop;
        else
            next_state <= wait_stop;
        end if;

        
        -------------------------------------------------------------------------
        -- Stop
        -------------------------------------------------------------------------
      when stop =>

        -- Jos stop on suoritettu onnistuneesti eli stop_status on ylhaalla
        -- siirrytaan start tilaan mikali lahetettavaa dataa on viela jaljella.
        -- Mikali kaikki on lahetetty siirrytaan finish tilaan. Jos stop_status
        -- on alhaalla pysytaan nykyisessa tilassa, silla stop ei ole viela valmis.
        if stop_done = '1' then
          if data_counter = data_count_c then
            next_state <= finish;
          else
            next_state <= wait_start;
          end if;
        else
          next_state <= stop;
        end if;
        

        -------------------------------------------------------------------------
        -- Finish
        -------------------------------------------------------------------------
      when finish =>

        -- Finish tilassa kaikki data on jo lahetetty joten tilassa pysytaan loppuaika
        next_state <= finish;

        -------------------------------------------------------------------------
        -- Others
        -------------------------------------------------------------------------
      when others =>
        
        -- Tanne ei pitaisi joutua ikina, mutta mikali jotain omituista
        -- tapahtuu niin siirrytaan init-tilaan ja aloitetaan koko homma alusta.
        next_state <= init;

    end case;

  end process comb_ns;

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------

  -- purpose: tilarekisteria hoitava prosessi
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: 
  sync_ps : process (clk, rst_n)
  begin  -- process sync_ps
    if rst_n = '0' then                 -- asynchronous reset (active low)

      --resetoidaan arvot alussa:

      -- Nykyiseksi tilaksi init
      curr_state_r <= init;

      -- Laskurit nollaan
      bit_counter  <= 0;
      byte_counter <= 0;
      data_counter <= 0;
      stop_start_delay_counter <= 0;

      -- Signaalit nollaan *** 
      finished_out     <= '0';
      send_register_r  <= (others => '0');
      nack_received    <= '0';
      byte_register_r  <= (others => '0');
      start_done       <= '0';
      ack_done         <= '0';
      stop_status      <= '0';
      stop_done <= '0';
      internal_param_status <= (others => '0');
      wait_ready <= '0';
      wait_counter <= 0;

      -- *** paitsi sdat_internal ykkoseen
      sdat_internal <= '1';
      sdat_inout <= 'Z';

    elsif clk'event and clk = '1' then  -- rising clock edge

      -- Siirretaan nykyiseksi tilaksi seuraava tila
      curr_state_r <= next_state;

      -- Siirretaan internal_param_status vektoriin ykkosbitti
      -- oikealle paikalle, jotta voidaan seurata konfiguroinnin
      -- etenemista.Jos seuraava tila on finish niin ei enaa
      -- siirreta ettei tule ylivuotoa.
      if next_state /= finish then
        internal_param_status(data_counter) <= '1';
      end if;

      -- Kasvatetaan laskureita sclk signaalin nousevalla reunalla
      if sclk_gen_signal = '0' and clk_counter = ((ref_clk_freq_g / i2c_freq_g) / 2) then

        -- Jos ollaan send_data tilassa niin kasvatetaan bittilaskuria
        if curr_state_r = send_data then
          bit_counter <= bit_counter + 1;

        end if;
      end if;

        -- Tiloissa tapahtuvat toiminnot
      if curr_state_r = start then

        -- Start tilan alussa nollataan stop_done
        -- signaali.
        stop_done <= '0';
        
        -- Startissa lasketaan sdat_internal
        -- kun sclk_out on ylhaalla ja nostetaan
        -- start_done signaali, seka nollataan nack_received,
        -- stop_status ja start_done signaalit kun haluttu aika on kulunut.
        -- Muussa tapauksessa kasvatetaan laskuria.
        if sclk_gen_signal = '1' then
          if stop_start_delay_counter = start_delay_c then    
            sdat_internal <= '0';
            start_done    <= '1';
            nack_received <= '0';
            stop_status   <= '0';
            stop_done <= '0';
            stop_start_delay_counter <= 0;
            wait_ready <= '0';
           else
            start_done <= '0';
            stop_start_delay_counter <= stop_start_delay_counter + 1;
          end if; 
        end if;
          
      elsif curr_state_r = stop then

        -- Stop tilan alussa nollataan start_done
        -- signaali
        start_done     <= '0';
        wait_ready <= '0';
        sdat_internal <= '0';
        
        if  sclk_gen_signal = '1' and clk_counter = ((ref_clk_freq_g / i2c_freq_g) / 2) then 
          -- *** ja stop_delay_counter on saavuttanut
          -- halutun arvon niin nostetaan stop done signaali
          -- ja sdat_internal signaali ylos seka nollataan laskuri
          if stop_start_delay_counter = stop_delay_c then

            stop_start_delay_counter <= 0;
            stop_done <= '1';
            sdat_internal <= '1';
            
            -- Jos kuittausvaiheessa vastaanotettiin NACK
            -- niin pidetaan datacounterin arvo samana
            if nack_received = '1' then
              data_counter <= data_counter;

            -- Muussa tapauksessa siirrytaan seuraavan datapaketin lahetykseen
            else
              data_counter <= data_counter + 1;
            end if;

          -- Jos ei olla valmiita niin pidetaan stop_done
          -- signaali alhaalla ja kasvatetaan laskuria.
          else
            stop_done <= '0';
            stop_start_delay_counter <= stop_start_delay_counter + 1;
          end if;
        end if;
      end if;

      if curr_state_r = send_data then

        -- Send data tilan alussa nollataan ack_done signaali
        ack_done <= '0';

        -- Asetetaan oikeat arvot lahetysrekistereihin
        send_register_r <= data_signal((data_count_c - data_counter) - 1);
        byte_register_r <= send_register_r((bit_count_c * (byte_cout_c - byte_counter) - 1)
                                           downto ((bit_count_c * ((byte_cout_c - 1) - byte_counter))));

        -- Kun sclk on alhaalla siirretaan sdat_internal signaaliin
        -- lahetettava bitti send_register_r:n oikealta kohdalta
        if bit_counter /= bit_count_c and bit_counter /= bit_count_c + 1 then
          if sclk_gen_signal = '0' and  clk_counter = ((ref_clk_freq_g / i2c_freq_g) / 4) then
            sdat_internal <= byte_register_r((bit_count_c - bit_counter) - 1);
          end if;
        end if;
        

      elsif curr_state_r = wait_ack then

        -- wait_ack tilan alussa asetetaan sdat_inout korkeaimpedassiseeen tilaan
        sdat_inout <= 'Z';
        
        -- Jos sdat_inout on yksi ja sclk_gen_signal on ylhaalla niin
        -- vastaanotettiin NACK. Nostetaan nack_received signaali ylos
        -- ja nollataan tavulaskuri.
        if sdat_inout = '1' and sclk_gen_signal = '1' and clk_counter = ((ref_clk_freq_g / i2c_freq_g) / 2) then
          nack_received <= '1';

        -- Muussa tapauksessa pidetaan nack_received signaali ennallaan.
        else
          nack_received <= nack_received;
        end if;

        -- Jos bittilaskuri menee nollaan on kuittaus saatu
        -- ja nostetaan ack_done signaali seka asetetaan nolla
        -- sdat_internal signaaliin start- tilaan siirtymista varten
        if sclk_gen_signal = '1' and clk_counter = ((ref_clk_freq_g / i2c_freq_g) / 2) then
          ack_done <= '1';
          sdat_internal <= '0';
          bit_counter <= 0;
          byte_counter <= byte_counter + 1;

          if byte_counter = (byte_cout_c - 1) then
            byte_counter <= 0;
            stop_status  <= '1';
          end if;
          
        -- Muussa tapauksessa pidetaan ack_done signaali alhaalla
        else
          ack_done <= '0';
        end if;
        
      end if;

      -- Jos ollaan finish tilassa
      -- niin nostetaan finish-signaali
      -- ja asetetaan sdat_inout signaaliin
      -- arvo 0
      if curr_state_r = finish then
        finished_out <= '1';
        sdat_internal <= '0';

      -- Mikali ei olla viela valmiita pidetaan finished_out
      -- signaali alhaalla.
      else
        finished_out <= '0';
      end if;

      if curr_state_r = init then
        sdat_internal <= '1';
      end if;

      -- Jos ollaan wait_ack tilassa tai menossa sinne niin asetetaan
      -- sdat_inout signaali korkeaimpedanssiseen tilaan.
      -- Muissa tiloissa asetetaan siihen sdat_internal
      -- signaalin arvo
      if next_state = wait_ack or curr_state_r = wait_ack then
        sdat_inout <= 'Z';
      else
        sdat_inout <= sdat_internal;
      end if;

      -- Jos ollaan wait_stop tilassa niin odotetaan
      -- SDAT-signaalin asettumista ennen stop-tilaan
      -- menoa.
       if curr_state_r = wait_stop then
          if wait_counter = wait_stop_c then
            wait_ready <=  '1';
            wait_counter <= 0;
          else
            wait_counter <= wait_counter + 1;
          end if;
        end if;

      if curr_state_r = wait_start then
          if wait_counter = wait_start_c then
            wait_ready <=  '1';
            wait_counter <= 0;
          else
            wait_counter <= wait_counter + 1;
          end if;
      end if;

      if next_state = wait_start or curr_state_r = wait_start then
        sdat_internal <= '1';
      end if;
      
    end if;
 
end process sync_ps;

-- Asetetaan param_status_out signaaliin internal_param_status
-- signaali, joka seuraa konfiguroinnin etenemista.
param_status_out <= internal_param_status;

end fsm;
