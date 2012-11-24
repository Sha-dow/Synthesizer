-------------------------------------------------------------------------------
-- Title      : Audio control testbench
-- Project    : 
-------------------------------------------------------------------------------
-- File       : tb_audio_ctrl.vhd
-- Author     : Hannu Ranta 
-- Company    : 
-- Created    : 2011-03-10
-- Last update: 2011/03/11
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Testbench for audio control
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-03-10  1.0      hannu   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_audio_ctrl is
end tb_audio_ctrl;

-------------------------------------------------------------------------------
--      ARKKITEHTUURIN MAARITTELY ALKAA
-------------------------------------------------------------------------------
architecture testbench of tb_audio_ctrl is

  -- vakioiden maarittely
  constant clk_period_c : time    := 50 ns;  -- kello
  constant data_width_c : integer := 16;     -- datan leveys

  constant step_one_c : integer := 2;  -- ensimmaisen aaltogeneraattorin askeleen koko
  constant step_two_c : integer := 6;  -- toisen aaltogeneraattorin askeleen koko

  constant sample_rate_c : integer := 48000;  -- naytteenottotaajuus
  constant ref_clk_c : integer := 18432000;  -- referenssikello

  constant sync_up_c : integer := 8000;  -- aika jolloin sync_clear signaali nostetaan
  constant sync_down_c : integer := 10000;  -- aika jolloin sync_clear lasketaan

  -- esitellaan audio_ctrl komponentti (DUV)
  component audio_ctrl
    generic (
      ref_clk_freq_g : integer;         -- referenssikellotaajuus
      data_width_g   : integer;         -- datan leveys
      sample_rate_g  : integer);        -- naytteenottotaajuus
    port (
      clk           : in  std_logic;    -- kello
      rst_n         : in  std_logic;    -- reset
      left_data_in  : in  std_logic_vector((data_width_g - 1) downto 0);  -- vasemman kanavan data sisaan
      right_data_in : in  std_logic_vector((data_width_g - 1) downto 0);  -- oikean kanavan data sisaan
      aud_bclk_out  : out std_logic;    -- bittikello ulos
      aud_data_out  : out std_logic;    -- data ulos
      aud_lrclk_out : out std_logic);  -- vasemman ja oikean kanavan kello ulos
  end component;

  -- esitellaan aaltogeneraattorikomponentti
  component wave_gen
    generic (
      width_g : integer;                -- laskurin leveys
      step_g  : integer);               -- askeleen koko
    port (
      clk           : in  std_logic;    -- kello
      rst_n         : in  std_logic;    -- reset
      sync_clear_in : in  std_logic;    -- aaltogeneroinnin nollaussignaali
      value_out     : out std_logic_vector((width_g - 1) downto 0));  -- ulostulo
  end component;

  -- audiokontrollerin malli
  component audio_codec_model
    generic (
      data_width_g : integer);          -- datan leveys
    port (
      rst_n        : in std_logic;      -- reset
      aud_data_in  : in std_logic;      -- audiodata sisaan
      aud_bclk_in  : in std_logic;      -- bittikello sisaan
      aud_lrclk_in : in std_logic;  -- vasemman ja oikean kanavan clk sisaan

      -- vasemman ja oikean kanavan arvo ulos
      value_left_out  : out std_logic_vector((data_width_g - 1) downto 0);
      value_right_out : out std_logic_vector((data_width_g - 1) downto 0)
      );   
  end component;

  -- tarvittavat signaalit
  signal clk        : std_logic := '0';  -- kello
  signal rst_n      : std_logic := '0';  -- reset
  signal sync_clear : std_logic := '0';  -- sync clear

  signal l_data_wg_actrl  : std_logic_vector((data_width_c - 1) downto 0);  -- vasemman kanavan aaltodata
  signal r_data_wg_actrl : std_logic_vector((data_width_c - 1) downto 0);  -- oikean kanavan aaltodata

  signal l_data_codec_tb : std_logic_vector((data_width_c - 1) downto 0);  -- vasemman kanavan ulostulo
  signal r_data_codec_tb : std_logic_vector((data_width_c - 1) downto 0);  -- oikean kanavan ulostulo

  signal aud_data : std_logic := '0';   -- datasignaali
  signal aud_lr_clk : std_logic := '0';  -- vasemman ja oikean kanavan clk signaali
  signal aud_bit_clk : std_logic := '0';  -- bittikellosignaali
  
begin  -- testbench

  left_wave : wave_gen
    generic map (
      width_g => data_width_c,
      step_g  => step_one_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => sync_clear,
      value_out     => l_data_wg_actrl);

  right_wave : wave_gen
    generic map (
      width_g => data_width_c,
      step_g  => step_two_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => sync_clear,
      value_out     => r_data_wg_actrl);

  audiocontrol: audio_ctrl
    generic map (
      ref_clk_freq_g => ref_clk_c,
      sample_rate_g  => sample_rate_c,
      data_width_g   => data_width_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      left_data_in  => l_data_wg_actrl,
      right_data_in => r_data_wg_actrl,
      aud_bclk_out  => aud_bit_clk,
      aud_data_out  => aud_data,
      aud_lrclk_out => aud_lr_clk);

   codec_model: audio_codec_model
     generic map (
       data_width_g => data_width_c)
     port map (
       rst_n           => rst_n,
       aud_data_in     => aud_data,
       aud_lrclk_in    => aud_lr_clk,
       aud_bclk_in     => aud_bit_clk,
       value_left_out  => l_data_codec_tb,
       value_right_out => r_data_codec_tb);

  -- nostetaan reset
  rst_n <= '1' after clk_period_c * 2;

  clk <= not clk after clk_period_c / 2;


  -- nostetaan ja lasketaan sync_clear_in signaali
 
  sync_clear <= '0',
                '1' after clk_period_c * sync_up_c,
                '0' after clk_period_c * sync_down_c;

end testbench;
