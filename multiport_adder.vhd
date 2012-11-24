-------------------------------------------------------------------------------
-- Title      : Multiport adder
-- Project    : 
-------------------------------------------------------------------------------
-- File       : multiport_adder.vhd
-- Author     : Hannu Ranta 
-- Company    : 
-- Created    : 2011-01-26
-- Last update: 2011/02/01
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Multiport vhdl adder
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-01-26  1.0      hannu   Created
-------------------------------------------------------------------------------

-- Maaritellaan kirjastot kayttoon
library ieee;
use ieee.std_logic_1164.all;

-- Luodaan entity multi_port_adder
entity multi_port_adder is

  generic (
    operand_width_g   : integer := 16;  -- Geneerinen parametri oletusarvolla 16
    num_of_operands_g : integer := 14);  -- Geneerinen parametri oletusarvolla 14

  port (
    clk         : in  std_logic;        -- Kellosignaali
    rst_n       : in  std_logic;        -- Alhaalla aktiivinen reset
    operands_in : in  std_logic_vector(((operand_width_g * num_of_operands_g) - 1) downto 0);  -- operandit sisaan
    sum_out     : out std_logic_vector((operand_width_g - 1) downto 0)  -- summa ulos
    );

end multi_port_adder;

-------------------------------------------------------------------------------
--  ----------------------------------------------------------------------------
-------------------------------------------------------------------------------

-- aloitetaan arkkitehtuurikuvaus
architecture structural of multi_port_adder is

  -- Esitellaan Adder-komponentti
  component adder
    generic (

      operand_width_g : integer);       -- Adder-komponentin operand_width_g niminen generic
    port (

      clk     : in  std_logic;          -- Kello
      rst_n   : in  std_logic;          -- Alhaalla aktiivinen reset
      a_in    : in  std_logic_vector((operand_width_g - 1) downto 0);  -- summattava sisaan
      b_in    : in  std_logic_vector((operand_width_g - 1) downto 0);  -- toinen summattava sisaan
      sum_out : out std_logic_vector(operand_width_g  downto 0));  -- summa ulos

  end component;

  type taulukko is array(((num_of_operands_g/2) - 1) downto 0) of std_logic_vector(operand_width_g downto 0);  -- Maaritellaan uusi tyyppi nimeltaan taulukko

  signal subtotal : taulukko;           -- Subtotal-niminen taulukko-tyyppinen signaali
  signal total    : std_logic_vector((operand_width_g + 1) downto 0);  -- Total niminen operand_width_g + 2 levyinen signaali

begin  -- structural

  -- Kytketaan ensimmainen summain toteutukseen.
  -- Sijoitetaan tulos subtotal taulukon alkioon 0.
  adder_1 : adder
    generic map (
      operand_width_g => operand_width_g)
    port map (
      clk             => clk,
      rst_n           => rst_n,
      a_in            => operands_in((operand_width_g - 1) downto 0),
      b_in            => operands_in(((operand_width_g * 2) - 1) downto operand_width_g),
      sum_out         => subtotal(0));

  --Kytketaan toinen summain toteutukseen.
  -- Sijoitetaan tulos subtotal taulukon alkioon 1.
  adder_2 : adder
    generic map (
      operand_width_g => operand_width_g)
    port map (
      clk             => clk,
      rst_n           => rst_n,
      a_in            => operands_in(((operand_width_g * 3) - 1) downto (operand_width_g * 2)),
      b_in            => operands_in(((operand_width_g * 4) - 1) downto (operand_width_g * 3)),
      sum_out         => subtotal(1));

  -- Lasketaan yhteen aiemmin saadut valitulokset, eli
  -- subtotal taulukon alkiot 0 ja 1.Tulos total-nimiseen vektoriin. 
  adder_3 : adder
    generic map (
      operand_width_g => (operand_width_g + 1))
    port map (
      clk             => clk,
      rst_n           => rst_n,
      a_in            => subtotal(0),
      b_in            => subtotal(1),
      sum_out         => total);

  -- Sijoitetaan sum_out ulostuloon total-vektorin arvo
  -- kahta eniten merkitsevaa bittia lukuunottamatta.
  sum_out <= total((operand_width_g - 1) downto 0);

  -- Jos operandeja ei ole 4 kappaletta keskeitetaan severity-failureen.
  assert (num_of_operands_g = 4) report "severity failure  -- num_of_operands_g not equal to 4" severity failure;

end structural;
