-------------------------------------------------------------------------------
-- Title      : Audio codec model
-- Project    : 
-------------------------------------------------------------------------------
-- File       : audio_codec_model.vhd
-- Author     : Hannu Ranta  
-- Company    : 
-- Created    : 2011-03-10
-- Last update: 2011/04/24
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Wolfson WM8731 audio codec model
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-03-10  1.0      hannu	Created
-------------------------------------------------------------------------------

-- esitellaan kirjastot
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity audio_codec_model is
  
  generic (
    data_width_g : integer := 16);      -- datan leveys
    
    port (
      rst_n           : in  std_logic;    -- reset
      aud_data_in     : in  std_logic;    -- data sisaan
      aud_bclk_in     : in  std_logic;    -- bittikello sisaan
      aud_lrclk_in    : in  std_logic;    -- vasemman ja oikean kanavan kello
      value_left_out  : out std_logic_vector((data_width_g - 1) downto 0);  -- vasemman kanavan data ulos
      value_right_out : out std_logic_vector((data_width_g - 1) downto 0));  -- oikean kanavan data ulos
    
end audio_codec_model;
    
-------------------------------------------------------------------------------
--      ARKKITEHTUURIN MAARITTELY ALKAA
-------------------------------------------------------------------------------


architecture rtl of audio_codec_model is

  -- esitellaan tilakoneen tilat ja luodaan signaali
  -- nykyiselle ja seuraavalle tilalle
  type state_type is (wait_input, read_left, read_right); 
  signal curr_state_r : state_type; -- nykyinen tila
  signal next_state : state_type; -- seuraava tila

  -- rekisterit vasemman ja oikean kanavan datalle
  signal left_data_r : std_logic_vector((data_width_g - 1) downto 0);
  signal right_data_r : std_logic_vector((data_width_g - 1) downto 0);

  signal counter : integer := 0;        -- laskuri vastaanotetuille biteille
  
begin  -- rtl

  -- purpose: tilarekisterin seuraavan tilan maaraava prosessi
  -- type   : sequential
  -- inputs : curr_state_r, aud_lrclk_in
  -- outputs: next_state
  comb_ns : process (curr_state_r, aud_lrclk_in)
  begin -- process comb_ns 

    case curr_state_r is

      -------------------------------------------------------------------------
      -- WAIT INPUT
      -------------------------------------------------------------------------
    when wait_input =>

      -- jos aud_lrclk_in = 1 siirrytaan read_left tilaan,
      -- muuten pysytaan nykyisessa
      if aud_lrclk_in = '1' then
        next_state <= read_left;
      else
        next_state <= wait_input;
      end if;

      -------------------------------------------------------------------------
      -- READ LEFT
      -------------------------------------------------------------------------
    when read_left =>

      -- jos aud_lrclk_in = 0 siirrytaan read_right tilaan,
      -- muuten pysytaan nykyisessa
      if aud_lrclk_in = '0' then
        next_state <= read_right;
      else
        next_state <= read_left;
      end if;

      -------------------------------------------------------------------------
      -- READ RIGHT
      -------------------------------------------------------------------------
    when read_right =>

      -- jos aud_lrclk_in = 1 siirrytaan read_left tilaan,
      -- muuten pysytaan nykyisessa
      if aud_lrclk_in = '1' then
        next_state <= read_left;
      else
        next_state <= read_right;
      end if;

       ------------------------------------------------------------------------
       -- OTHERS
       ------------------------------------------------------------------------
    when others =>

      -- tanne ei pitaisi joutua mutta jos joudutaan niin nollataan tilakone
      next_state <= wait_input;  
    end case;
    
  end process comb_ns;

-- purpose: tilarekisteria hoitava prosessi
-- type   : sequential
-- inputs : aud_bclk_in, rst_n
-- outputs: next_state
sync_ps: process (aud_bclk_in, rst_n)
begin  -- process sync_ps
  if rst_n = '0' then                   -- asynchronous reset (active low)

    -- asetetaan resetissa tilaksi wait_input
    -- ja nollataan laskuri seka rekisterit ja ulostulot
    curr_state_r <= wait_input;
    counter <= 0;
    right_data_r <= (others => '0');
    left_data_r <= (others => '0');
    value_left_out <= (others => '0');
    value_right_out <= (others => '0');
    
  elsif aud_bclk_in'event and aud_bclk_in = '0' then  -- falling clock edge

    -- laskevalla kellon reunalla siirretaan next_state curr_state_r rekisteriin
    curr_state_r <= next_state;

    -- jos laskuri saavuttaa oikean arvon niin nollataan se
    if counter = (data_width_g - 1) then

      counter <= 0;

      -- siirretaan oikea rekisteri ulostuloon
      -- ja nollataan toinen jotta se on valmiina
      -- vastaanottamaan dataa.
      if curr_state_r = read_left then
        value_right_out <= right_data_r;
        right_data_r <= (others => '0');
      elsif curr_state_r = read_right then
        value_left_out <= left_data_r;
        left_data_r <= (others => '0');
      else
        -- jos paadytaan tanne niin nollataan kumpikin ulostulo
        value_left_out <= (others => '0');
        value_right_out <= (others => '0');
      end if;

      -- muussa tapauksessa jatketaan laskurin kasvatusta
    else
      counter <= counter + 1;     
    end if;

    -- siirretaan aud_data_in sisaantulosta saatu bitti
    -- oikealle kohdalle oikeaan rekisteriin
    if next_state = read_right then
      left_data_r((data_width_g - counter) - 1) <= aud_data_in;
    elsif next_state = read_left then
      right_data_r((data_width_g - counter) - 1) <= aud_data_in;
    else
      -- jos paadytaan tanne niin nollataan rekisterit
      right_data_r <= (others => '0');
      left_data_r <= (others => '0');
    end if;
    
  end if;
end process sync_ps;
end rtl;
      
      
      
