-------------------------------------------------------------------------------
-- Title      : Ripple Carry adder
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ripple_carry_adder.vhd
-- Author     : Hannu Ranta 
-- Company    : 
-- Created    : 2011-01-13
-- Last update: 2011-01-13
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-01-13  1.0      hannu   Created
-------------------------------------------------------------------------------


-- Library declarations

library ieee;
use ieee.std_logic_1164.all;

-- Entity declaration
-- Ports: a_in  3-bit std_logic_vector
--        b_in  3-bit std_logic_vector
--        s_out 4-bit std_logic_vector

entity ripple_carry_adder is
  
  port (
    a_in  : in  std_logic_vector(2 downto 0);  -- 3 bit input
    b_in  : in  std_logic_vector(2 downto 0);  -- 3 bit input
    s_out : out std_logic_vector(3 downto 0)   -- 4 bit output
    );     

end ripple_carry_adder;


-------------------------------------------------------------------------------

-- Architecture definition
architecture gate of ripple_carry_adder is

-- internal signal declarations:

  signal c        : std_logic := '0';   -- internal signal 1
  signal d        : std_logic := '0';   -- internal signal 2
  signal e        : std_logic := '0';   -- internal signal 3
  signal f        : std_logic := '0';   -- internal signal 4
  signal g        : std_logic := '0';   -- internal signal 5
  signal h        : std_logic := '0';   -- internal signal 6
  signal carry_ha : std_logic := '0';   -- carry bit from half adder
  signal carry_fa : std_logic := '0';   -- carry bit from full adder
  
begin  -- gate

  -- Signal assignments

  s_out(0) <= a_in(0) xor b_in(0);	-- a_in(0) xor b_in(0) to s_out(0) output
  carry_ha <= a_in(0) and b_in(0);	-- a_in(0) and b_in(0) to carry_ha 

  c        <= a_in(1) xor b_in(1);	-- a_in(1) xor b_in(1) to c
  s_out(1) <= c xor carry_ha;		-- c xor carry_ha to s_out(1) output

  d <= c and carry_ha;			-- c and carry_ha to d
  e <= a_in(1) and b_in(1);		-- a_in(1) and b_in(1) to e

  carry_fa <= d or e;			-- d or e to carry_fa

  f        <= a_in(2) xor b_in(2);	-- a_in(2) xor b_in(2) to f
  s_out(2) <= f xor carry_fa;		-- f xor carry_fa to s_out(2) output

  g <= f and carry_fa;			-- f and carry_fa to g
  h <= a_in(2) and b_in(2);		-- a_in(2) and b_in(2) to h

  s_out(3) <= g or h;			-- g or h to s_out(3) output
  
end gate;
