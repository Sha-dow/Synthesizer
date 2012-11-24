-------------------------------------------------------------------------------
-- Title      : Audio Control
-- Project    : 
-------------------------------------------------------------------------------
-- File       : audio_ctrl.vhd
-- Author     : Hannu Ranta 
-- Company    : 
-- Created    : 2011-03-04
-- Last update: 2011/04/24
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Control unit for Wolfson WM8731
--                    audio circuit
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-03-04  1.0      hannu   Created
-------------------------------------------------------------------------------

-- esitellaan kirjastot
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity audio_ctrl is

  generic (
    ref_clk_freq_g : integer := 18432600;  -- referenssikellotaajuudelle generic
    sample_rate_g  : integer := 48000;  -- naytteenottotaajuudelle generic
    data_width_g   : integer := 16);    -- datan leveyden maaraama generic

  port (
    clk           : in  std_logic;      -- kellosignaali sisaan
    rst_n         : in  std_logic;      -- reset sisaan
    left_data_in  : in  std_logic_vector((data_width_g - 1) downto 0);  -- vasemman kanavan data sisaan
    right_data_in : in  std_logic_vector((data_width_g - 1) downto 0);  -- oikean kanavan data sisaan
    aud_bclk_out  : out std_logic;      -- bittikello ulos
    aud_data_out  : out std_logic;      -- databitti ulos
    aud_lrclk_out : out std_logic);     -- vasemman ja oikean kanavan kello ulos

end audio_ctrl;

-------------------------------------------------------------------------------
-- Arkkitehtuurin maarittely alkaa
-------------------------------------------------------------------------------

architecture audio_ctrl of audio_ctrl is

  signal left_register_r  : std_logic_vector((data_width_g - 1) downto 0);  -- rekisteri vasemmalle signaalille
  signal right_register_r : std_logic_vector((data_width_g - 1) downto 0);  -- rekisteri oikealle signaalille

  signal int_bit_clk         : std_logic := '0';  -- sisainen bittikello
  signal bit_clk_cycle       : integer   := (((ref_clk_freq_g / (sample_rate_g * data_width_g * 2)) - 1) / 2);  -- bit_clk signaalin taajuutta ohjaava laskuri
  signal int_bit_clk_counter : integer   := 0;  -- laskuri sisaiselle bittikellolle

  signal left_right_counter : integer := 0;  -- laskuri molempien kanavien ulostulolle
  signal int_channel_sel : std_logic := '0';  -- kanavan valinta

  signal aud_data : std_logic := '0';   -- datasignaali

begin  -- audio_ctrl

  -- purpose: generoi bit_clk signaalin
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: bit_clk
  bit_clk_gen : process (clk, rst_n)

  begin  -- process bit_clk_gen

    if rst_n = '0' then                 -- asynchronous reset (active low)

      -- asetetaan int_bit_clk resetissa nollaan
      int_bit_clk <= '0';

    elsif clk'event and clk = '1' then  -- rising clock edge

      -- jos int_bit_clk_counter on sama kuin haluttu jakso
      -- invertoidaan int_bit_clk ja nollataan laskuri
      if int_bit_clk_counter = (bit_clk_cycle) then
        
        int_bit_clk_counter <= 0;
        int_bit_clk         <= not int_bit_clk;

      -- muuten kasvatetaan laskuria
      else
        int_bit_clk_counter <= int_bit_clk_counter + 1;
      end if;
    end if;
  end process bit_clk_gen;

  -- sijoitetaan int_bit_clk aud_bclk_out ulostuloon
  aud_bclk_out <= int_bit_clk;


  -- purpose: lrclk signaalin generointi
  -- type : sequential
  -- inputs : clk, rst_n
  -- outputs: int_channel_sel
  lrgen : process (clk, rst_n)
  begin  -- process lrgen
    if rst_n = '0' then                 -- asynchronous reset (active low)

      -- asetetaan int_channel_sel, left_register_r ja right_register_r
      -- seka aud_data nollaan resetissa
      int_channel_sel        <= '0';
      left_register_r        <= (others => '0');
      right_register_r       <= (others => '0');
      aud_data <= '0';
      
    elsif clk'event and clk = '1' then  -- rising clock edge

      -- jos seka int_bit_clk = 0 ja int_bit_clk_counter on halutun jakson
      -- suuruinen ...
      if int_bit_clk = '1' and (int_bit_clk_counter = bit_clk_cycle) then

        -- ... ja jos left_right_counter on datajakson mittainen
        if left_right_counter = (data_width_g - 1) then
          
          -- invertoidaan int_channel_sel ja nollataan laskuri
          int_channel_sel    <= not int_channel_sel;
          left_right_counter <= 0;

          -- asetetaan sisaantuloarvot rekisteriin
          right_register_r   <= right_data_in;
          left_register_r    <= left_data_in;
          

        -- muussa tapauksessa kasvatetaan laskuria ja luetaan databitti
        -- oikeasta rekisterista aud_data signaaliin
        else
          
          if int_channel_sel = '1' then
            --luetaan MSB vasemman kanavan rekisterista aud_data signaaliin
            aud_data <= left_register_r((data_width_g - 1) - left_right_counter);

            -- jos int_channel_sel = 0
          elsif int_channel_sel = '0' then
            -- luetaan MSB oikean kanavan rekisterista aud_data signaaliin
            aud_data <= right_register_r((data_width_g - 1) - left_right_counter);
          else
            aud_data <= '0';
          end if;

          left_right_counter <= left_right_counter + 1;
         
        end if;
      end if;
    end if;
  end process lrgen;

  -- sijoitetaan int_channel_sel signaali aud_lrclk_out ulostuloon
  aud_lrclk_out <= int_channel_sel;

  -- sijoitetaan aud_data signaali aud_data_out ulostuloon
  aud_data_out <= aud_data;
  
end audio_ctrl;
