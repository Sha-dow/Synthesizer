-------------------------------------------------------------------------------
-- Title      : Synthesizer
-- Project    : 
-------------------------------------------------------------------------------
-- File       : synthesizer.vhd
-- Author     : Hannu Ranta  
-- Company    : 
-- Created    : 2011-03-24
-- Last update: 2011/03/25
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Structural description of synthesizer
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-03-24  1.0      hannu   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity synthesizer is

  generic (
    clk_freq_g    : integer := 18432000;  -- oletuskello
    sample_rate_g : integer := 48000;     -- naytteenottotaajuus
    data_width_g  : integer := 16;        -- datan leveys
    n_keys_g      : integer := 4);        -- painonappien maara

  port (
    clk           : in  std_logic;      -- kello
    rst_n         : in  std_logic;      -- reset
    keys_in       : in  std_logic_vector((n_keys_g - 1) downto 0);  -- nappien sisaantulo
    aud_bclk_out  : out std_logic;      -- bittikello ulos
    aud_data_out  : out std_logic;      -- data ulos
    aud_lrclk_out : out std_logic);     -- kanavan valinta ulos

end synthesizer;

-------------------------------------------------------------------------------
-- ARKKITEHTUURIN MAARITTELY
-------------------------------------------------------------------------------

architecture structural of synthesizer is

  -- esitellaan vakiot
  constant step_one_c   : integer := 1;  -- aaltogeneraattorille nro 1 askel
  constant step_two_c   : integer := 2;  -- aaltogeneraattorille nro 2 askel
  constant step_three_c : integer := 4;  -- aaltogeneraattorille nro 3 askel
  constant step_four_c  : integer := 8;  -- aaltogeneraattorille nro 4 askel

  -- esitellaan tarvittavat komponentit

  -----------------------------------------------------------------------------
  -- AALTOGENERAATTORI
  -----------------------------------------------------------------------------

  component wave_gen
    generic (
      width_g       :     integer;      -- laskurin leveys bitteina
      step_g        :     integer);     -- askeleen koko
    port (
      clk           : in  std_logic;    -- kello
      rst_n         : in  std_logic;    -- alhaalla aktiivinen reset
      sync_clear_in : in  std_logic;    -- aaltogeneraattorin nollaussignaali
      value_out     : out std_logic_vector((width_g - 1) downto 0));  -- ulostulo leveydella width_g
  end component;

  -----------------------------------------------------------------------------
  -- MULTIPORT-ADDER
  -----------------------------------------------------------------------------

  component multi_port_adder
    generic (
      operand_width_g   :     integer;  -- operandin leveys
      num_of_operands_g :     integer);  -- operandien maara
    port (
      clk               : in  std_logic;  -- kello
      rst_n             : in  std_logic;  -- alhaalla aktiivinen reset
      operands_in       : in  std_logic_vector(((operand_width_g * num_of_operands_g) - 1) downto 0);  -- operandit sisaan
      sum_out           : out std_logic_vector((operand_width_g - 1) downto 0));  -- summa ulos
  end component;

  -----------------------------------------------------------------------------
  -- AUDIO CONTROL
  -----------------------------------------------------------------------------

  component audio_ctrl
    generic (
      ref_clk_freq_g :     integer;     -- referenssikello
      sample_rate_g  :     integer;     -- naytteenottotaajuus
      data_width_g   :     integer);    -- datan leveys
    port (
      clk            : in  std_logic;   -- kello
      rst_n          : in  std_logic;   -- alhaalla aktiivinen reset
      left_data_in   : in  std_logic_vector((data_width_g - 1) downto 0);  -- vasemman kanavan data sisaan
      right_data_in  : in  std_logic_vector((data_width_g - 1) downto 0);  -- oikean kanavan data sisaan
      aud_bclk_out   : out std_logic;   -- bittikello ulos
      aud_data_out   : out std_logic;   -- databitti ulos
      aud_lrclk_out  : out std_logic);  -- vasemman ja oikean kanavan valintakello ulos
  end component;

  -----------------------------------------------------------------------------

  -- komponenttien valiset signaalit

  signal wave_data_to_adder : std_logic_vector(((data_width_g * n_keys_g) - 1) downto 0);  -- data aaltogeneraattoreilta summaimelle
  signal data_to_aud_ctrl   : std_logic_vector((data_width_g - 1) downto 0);  -- data summaimelta kontrollerille

begin  -- structural

  -- Luodaan nelja erilaista aaltogeneraattori
  -- Eri step-arvolla jokaisesta tulee eri taajuus
  
  wavegen_yksi : wave_gen
    generic map (
      width_g       => data_width_g,
      step_g        => step_one_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => keys_in(0),
      value_out     => wave_data_to_adder((data_width_g - 1) downto 0) );

  wavegen_kaksi : wave_gen
    generic map (
      width_g       => data_width_g,
      step_g        => step_two_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => keys_in(1),
      value_out     => wave_data_to_adder(((2 * data_width_g) - 1) downto data_width_g));

  wavegen_kolme : wave_gen
    generic map (
      width_g       => data_width_g,
      step_g        => step_three_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => keys_in(2),
      value_out     => wave_data_to_adder(((3 * data_width_g) - 1) downto (2 * data_width_g)));

  wavegen_nelja : wave_gen
    generic map (
      width_g       => data_width_g,
      step_g        => step_four_c)
    port map (
      clk           => clk,
      rst_n         => rst_n,
      sync_clear_in => keys_in(3),
      value_out     => wave_data_to_adder(((4 * data_width_g) - 1) downto (3 * data_width_g)));

  -- Luodaan summain
  adder : multi_port_adder
    generic map (
      operand_width_g   => data_width_g,
      num_of_operands_g => n_keys_g)
    port map (
      clk               => clk,
      rst_n             => rst_n,
      operands_in       => wave_data_to_adder,
      sum_out           => data_to_aud_ctrl);

  --Luodaan kontrolleri
  control : audio_ctrl
    generic map (
      ref_clk_freq_g => clk_freq_g,
      sample_rate_g  => sample_rate_g,
      data_width_g   => data_width_g)
    port map (
      clk            => clk,
      rst_n          => rst_n,
      left_data_in   => data_to_aud_ctrl,
      right_data_in  => data_to_aud_ctrl,
      aud_bclk_out   => aud_bclk_out,
      aud_data_out   => aud_data_out,
      aud_lrclk_out  => aud_lrclk_out);

end structural;
