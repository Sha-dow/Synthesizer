-------------------------------------------------------------------------------
-- Title      : Wave Generator
-- Project    : 
-------------------------------------------------------------------------------
-- File       : wave_gen.vhd
-- Author     : Hannu Ranta  
-- Company    : 
-- Created    : 2011-02-16
-- Last update: 2011/03/24
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Generates trianglewave
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-02-16  1.0      hannu   Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wave_gen is

  generic (
    width_g : integer;                  -- laskurin leveys bitteina
    step_g  : integer);                 -- askeleen koko

  port (
    clk           : in  std_logic;      -- kellosignaali
    rst_n         : in  std_logic;      -- alhaalla aktiivinen reset
    sync_clear_in : in  std_logic;      -- aaltogeneroinnin nollaussignaali
    value_out     : out std_logic_vector((width_g - 1) downto 0));  -- ulostulo leveydella width_g

end wave_gen;

-------------------------------------------------------------------------------
--Arkkitehtuurin maarittely alkaa
-------------------------------------------------------------------------------

architecture wave of wave_gen is

  constant max_value_c : integer := ((((2 ** (width_g - 1)) - 1) / step_g) * step_g);  -- laskurin maksimiarvo
  constant min_value_c : integer := - max_value_c;  -- laskurin minimiarvo

  signal counter : std_logic_vector((width_g - 1) downto 0);  -- laskurisignaali

begin  -- wave

  -- purpose: muodostaa aaltosignaalin muuttamalla laskurin arvoa
  -- type   : sequential
  -- inputs : clk, rst_n, sync_clear_in
  -- outputs: value_out
  counter_process : process (clk, rst_n)

    variable cur_step_v      : integer := step_g;  -- prosessin sisainen askeleen arvo
    variable counter_value_v : integer := 0;  -- laskurin arvon mukainen integer

  begin  -- process counter
    if rst_n = '0' then                 -- asynchronous reset (active low)

      -- nollataan counter-signaali resetissa
      counter <= (others => '0');

    elsif clk'event and clk = '1' then  -- rising clock edge

      --jos sync_clear_in nostetaan ylös niin nollataan laskuri ja signaalit.
      if sync_clear_in = '1' then
        counter_value_v := 0;
        counter <= (others => '0');
        cur_step_v      := step_g;

      else

        -- muussa tapauksessa kasvatetaan laskurin arvoa.
        counter_value_v := (counter_value_v + cur_step_v);

        -- jos laskuri saavuttaa ala- tai ylarajan muutetaan kerrotaan askeleen
        -- arvo -1:lla jolloin laskentasuunta vaihtuu.
        if ((counter_value_v = max_value_c) or (counter_value_v = min_value_c)) then
          cur_step_v := (cur_step_v * (- 1));
        end if;

      end if;

      -- laitetaan laskurin arvo counter-signaaliin
      counter <= std_logic_vector(to_signed(counter_value_v, width_g));

    end if;
  end process counter_process;

  --sijoitetaan counter -signaali ulostuloon
  value_out <= counter;

end wave;
