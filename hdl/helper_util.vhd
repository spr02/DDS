----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 16.01.2017 17:44:50
-- Design Name: 
-- Module Name: helper_util - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


package helper_util is

    function ceil_log2 (x: in integer) return integer;
    function ceil_div2 (x: in integer) return integer;
    function resize_and_align_slv (slv : in std_logic_vector; from_frac : in integer; to_width : in integer; to_frac : in integer) return std_logic_vector;
    function resize_and_align_sgn (sgn : in signed; from_frac : in integer; to_width : in integer; to_frac : in integer) return signed;
    function resize_and_align_usg (usg : in unsigned; from_frac : in integer; to_width : in integer; to_frac : in integer) return unsigned;
end package helper_util;

package body helper_util is


    function ceil_log2 (x: in integer) return integer is
        variable tmp    : integer := x;
        variable ret    : integer := 0;
    begin
        while tmp > 1 loop
            ret := ret + 1;
            tmp := tmp / 2;
        end loop;
        return ret;
    end function ceil_log2;

    function ceil_div2 (x: in integer) return integer is
        variable ret : integer;
    begin
        if x rem 2 = 0 then -- x even?
            ret := x/2;
        else
            ret := 1 + x/2;
        end if;
        return ret;
    end function ceil_div2;
    
    function resize_and_align_slv (slv : in std_logic_vector; from_frac : in integer; to_width : in integer; to_frac : in integer) return std_logic_vector is
        variable slv_in         : signed((slv'length - 1) downto 0);
        variable ret            : signed((to_width - 1) downto 0);
    begin
        slv_in := signed(slv);
        if to_frac > from_frac then
            ret := resize(slv_in, to_width); -- first resize (in case of to_width > from_width we would loose integer bits, if not done first)
            ret := shift_left(ret, to_frac - from_frac);
        elsif to_frac < from_frac then
            slv_in := shift_right(slv_in, from_frac - to_frac);
            ret := resize(slv_in, to_width); -- first rightshift, then resize
        else
            ret := resize(slv_in, to_width); -- simply truncate integer bits
        end if;
        return std_logic_vector(ret);
    end function resize_and_align_slv;
    
    function resize_and_align_sgn (sgn : in signed; from_frac : in integer; to_width : in integer; to_frac : in integer) return signed is
        variable sgn_in         : signed((sgn'length - 1) downto 0);
        variable ret            : signed((to_width - 1) downto 0);
    begin
        sgn_in := sgn;
        if to_frac > from_frac then
            ret := resize(sgn_in, to_width); -- first resize (in case of to_width > from_width we would loose integer bits, if not done first)
            ret := shift_left(ret, to_frac - from_frac);
        elsif to_frac < from_frac then
            sgn_in := shift_right(sgn_in, from_frac - to_frac);
            ret := resize(sgn_in, to_width); -- first rightshift, then resize
        else
            ret := resize(sgn_in, to_width); -- simply truncate integer bits
        end if;
        return ret;
    end function resize_and_align_sgn;
    
    function resize_and_align_usg (usg : in unsigned; from_frac : in integer; to_width : in integer; to_frac : in integer) return unsigned is
        variable usg_in         : unsigned((usg'length - 1) downto 0);
        variable ret            : unsigned((to_width - 1) downto 0);
    begin
        usg_in := usg;
        if to_frac > from_frac then
            ret := resize(usg_in, to_width); -- first resize (in case of to_width > from_width we would loose integer bits, if not done first)
            ret := shift_left(ret, to_frac - from_frac);
        elsif to_frac < from_frac then
            usg_in := shift_right(usg_in, from_frac - to_frac);
            ret := resize(usg_in, to_width); -- first rightshift, then resize
        else
            ret := resize(usg_in, to_width); -- simply truncate integer bits
        end if;
        return ret;
    end function resize_and_align_usg;
    
  
end package body helper_util;
