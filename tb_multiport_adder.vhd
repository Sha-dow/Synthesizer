-------------------------------------------------------------------------------
-- Title      : Multiport Adder Testbench
-- Project    : 
-------------------------------------------------------------------------------
-- File       : tb_multiport_adder.vhd
-- Author     : Hannu Ranta  
-- Company    :
-- Created    : 2011-01-20
-- Last update: 2011/02/10
-- Platform   : 
-------------------------------------------------------------------------------
-- Description: TestBench for multiport adder
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011/02/01  1.0      ranta5  Created
-------------------------------------------------------------------------------

-- Esitellaan kaytettavat kirjastot
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Aloitetaan entityn maarittely
entity tb_multi_port_adder is

  generic (
    operand_width_g : integer := 3);    -- operand_width_g niminen generic oletusarvolla 3
end tb_multi_port_adder;

-------------------------------------------------------------------------------
-- Arkkitehtuurin maarittely alkaa
-------------------------------------------------------------------------------

architecture testbench of tb_multi_port_adder is

  -- Esitellaan kaytetyt vakiot
  constant clk_period_c      : time    := 10 ns;  -- Vakio kellojakson pituudelle
  constant num_of_operands_c : integer := 4;  -- Vakio joka maarittaa operandien maaran
  constant DUV_delay_c       : integer := 2;  -- Vakio DUV:in viiveelle

  -- Esitellaan signaalit
  signal clk            : std_logic := '0';  -- Signaali kellolle alkuarvolla 0
  signal rst_n          : std_logic := '0';  -- Alhaalla aktiivinen reset alkuarvolla 0
  signal output_valid_r : std_logic_vector(DUV_delay_c downto 0);  -- Siirtorekisteri viiveen kompensointiin
  signal operands_r     : std_logic_vector(15 downto 0);  -- Testattavan lohkon sisaanmenoon kytkettava signaali
  signal sum            : std_logic_vector(operand_width_g downto 0);  -- DUV:n tuottama ulostulo

  -- Esitellaan avattavat tiedostot
  file input_f       : text open read_mode is "input.txt";  -- Lukee sisaan tiedoston input.txt
  file ref_results_f : text open read_mode is "ref_results_4b.txt";  -- Lukee sisaan tiedoston ref_results.txt
  file output_f      : text open write_mode is "output.txt";  -- Kirjoittaa tiedostoon output.txt


  -- Otetaan kayttoon multi_port_adder niminen komponentti
  component multi_port_adder
    generic (
      operand_width_g   :     integer;  -- operands_width_g niminen generic
      num_of_operands_g :     integer);  -- num_of_operands_g niminen generic
    port (
      clk               : in  std_logic;  -- Kellosignaali
      rst_n             : in  std_logic;  -- Alhaalla aktiivinen reset
      operands_in       : in  std_logic_vector(((operand_width_g * num_of_operands_g) - 1) downto 0);  -- Operandit sisaan
      sum_out           : out std_logic_vector((operand_width_g - 1) downto 0));  -- Summa ulos
  end component;

begin  -- testbench



  -- purpose: Generoidaan kellosignaali
  -- type   : combinational
  -- inputs : clk
  -- outputs: 'clk
  clock_gen : process (clk)
  begin  -- process clock_gen
    clk <= not clk after (clk_period_c / 2);
  end process clock_gen;

  -- Nostetaan reset ylos 4 kellojakson kuluttua
  rst_n <= '1' after (clk_period_c * 4);

  -- Luodaan multiport adderista istanssi ja kytketaan signaalit
  DUV : multi_port_adder
    generic map (
      operand_width_g   => (operand_width_g + 1),
      num_of_operands_g => num_of_operands_c)
    port map (
      clk               => clk,
      rst_n             => rst_n,
      operands_in       => operands_r,
      sum_out           => sum);

  -- purpose: Synkroninen prosessi syotetiedostojen lukemiselle
  -- type   : sequential
  -- inputs : clk, rst_n
  -- outputs: operands_r, output_valid_r
  input_reader : process (clk, rst_n)

    -- Esitellaan kaytetyt variablet
    variable rivi_v  : line;            -- variable yhdelle riville
    type kokonaislukutaulu is array ((num_of_operands_c - 1) downto 0) of integer;  -- taulukko kokonaisluvuille
    variable luvut_v : kokonaislukutaulu;  -- taulukko tyyppia kokonaislukutaulu neljalle luvulle

  begin  -- process input reader

    if rst_n = '0' then                 -- asynchronous reset (active low)
      --resetoidaan operands_r ja output_valid_r arvoon 0
      operands_r     <= (others => '0');
      output_valid_r <= (others => '0');

    elsif clk'event and clk = '1' then  -- rising clock edge

      --output_valid_r vektorin 0-bitin arvoksi 1 ja shiftaus vasemmalle
      output_valid_r <= output_valid_r((DUV_delay_c - 1) downto 0) & '1';

      -- Jos tiedoston loppua ei ole saavutettu ...
      if (not endfile(input_f)) then

        -- ...luetaan input_f tiedostosta rivi rivi_v muuttujaan
        readline(input_f, rivi_v);

        --luetaan rivilta arvot taulukkoon silmukassa
        for i in (num_of_operands_c - 1) downto 0 loop
          read(rivi_v, luvut_v(i));
          operands_r(((num_of_operands_c * (i + 1)) - 1) downto (num_of_operands_c * i)) <= std_logic_vector(to_signed(luvut_v(i), 4));
        end loop;

      end if;

    end if;
  end process input_reader;

  -- purpose: Synkroninen prosessi tarkastajalle
  -- type   : sequential
  -- inputs : clk, rst_n, output_valid_r 
  -- outputs: output_f
  checker : process (clk, rst_n)

    -- Esitellaan kaytetyt variablet
    variable refrivi_v      : line;     -- Tarkastusrivi
    variable tulos_v        : integer;  -- Tulos
    variable ulostulorivi_v : line;     -- Ulostulorivi

  begin  -- process checker

    if rst_n = '0' then                 -- asynchronous reset (active low)
      --resetoidaan sum-signaali arvoon 0
      --sum <= (others => '0');

    elsif clk'event and clk = '1' then  -- rising clock edge

      -- Jos siirtorekisterin ylin bitti on yksi aloitetaan tarkistusprosessi
      if output_valid_r(DUV_delay_c) = '1' then

        -- Jos tarkistustiedoston loppua ei olla saavutettu 
        if (not endfile(ref_results_f)) then

          -- Luetaan tarkistustiedostosta rivi ja rivilta arvo
          readline(ref_results_f, refrivi_v);
          read(refrivi_v, tulos_v);

          -- Tarkistetaan vastaako laskettu arvo luettua arvoa. Jos ei niin
          -- heitetaan Assert ja ilmoitetaan testaajalle.
          assert ((to_integer(signed(sum))) = tulos_v) report "Value is not equal to reference value!" severity failure;

          -- Kirjoitetaan laskettu arvo output.txt tiedostoon
          write(ulostulorivi_v, (to_integer(signed(sum))));
          writeline(output_f, ulostulorivi_v);

        else
          -- Jos simulaatio menee onnistuneesti lapi ilmoitetaan sen paattymisesta
          assert false report "Simulation done!" severity failure;
        end if;

      end if;

    end if;
  end process checker;

end testbench;
