-------------------------------------------------------------------------------
-- Title      : Adder
-- Project    : 
-------------------------------------------------------------------------------
-- File       : adder.vhd
-- Author     : Hannu Ranta 
-- Company    : 
-- Created    : 2011-01-20
-- Last update: 2011/01/20
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: RTL-Adder component
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-01-20  1.0      hannu   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adder is

  -- Generic-maarittelyt
  generic (
    operand_width_g : integer  -- luodaan integer-tyyppinen geneerinen parametri
    );  

  -- Porttien maarittelyt
  port (
    clk     : in  std_logic;            -- kello
    rst_n   : in  std_logic;            -- alaalla aktiivinen reset
    a_in    : in  std_logic_vector(operand_width_g - 1 downto 0);  -- summattava sisaan
    b_in    : in  std_logic_vector(operand_width_g - 1 downto 0);  -- toinen summattava sisaan
    sum_out : out std_logic_vector(operand_width_g downto 0)  -- summa ulos
    );  

end adder;

-------------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-------------------------------------------------------------------------------
architecture rtl of adder is

  -- Rekisteriulostulon maarittely
  signal tulos_r : signed(operand_width_g downto 0);  -- valisignaali tulokselle

begin  -- rtl

  -- Sijoitetaan rekisterin tulos arvo lohkon ulostuloon
  sum_out <= std_logic_vector(tulos_r);

  -- purpose: laskee yhteenlaskun prosessin sisassa
  -- type   : sequential
  -- inputs : clk, rsn_n, a_in, b_in
  -- outputs: sum_out

  summa : process (clk, rst_n)
  begin  -- process summa
    if rst_n = '0' then                 -- asynchronous reset (active low)
     
      tulos_r <= (others => '0');       -- alustetaan tulosrekisteri
      
    elsif clk'event and clk = '1' then  -- rising clock edge

      -- Lasketaan a_in:in ja b_in:in arvo yhteen  muuttamalla niiden tyyppi
      -- ensin signed-muotoon ja muuttamalla sitten niiden koko samaksi kuin
      -- tulos_r:an koko. Sijoitetaan tulos tulosrekisteriin.
      tulos_r <= (resize(signed(a_in), operand_width_g + 1) + resize(signed(b_in), operand_width_g + 1));
      
    end if;
  end process summa;

end rtl;
