library IEEE;
use IEEE.std_logic_1164.All;
use IEEE.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;        
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_en : out std_logic;
        o_we : out std_logic;
        o_data: out std_logic_vector(7 downto 0)
    );
end project_reti_logiche;

architecture FSM of project_reti_logiche is
    type state_type is (RST, START, COLONNE, SET_ADD1, RIGHE, SET_ADD2, CFR, SET_IMG, SET_ADD3, SETUP_VALUES, SHIFT, READ_STATE, WRITE_SAVE, DELTA, NEW_PIXEL, READ_SAVE, DONE);
    signal next_state, current_state: state_type;
    signal o_address_next, o_address_r, o_address_w, o_address_cur: std_logic_vector(15 downto 0);
    signal min_pixel, delta_value,  cfr_pixel, current_pixel_value, max_pixel, new_pixel_value : unsigned(7 downto 0);
    signal temp_pixel_value: unsigned (15 downto 0);
    signal shift_level : integer range 0 to 8 := 0;
    signal n_col, n_riga : integer range 0 to 128 := 0;

 begin
    reg_state: process(i_clk, i_rst)
    begin
        if (i_rst='1') then
            current_state <= RST;
        elsif rising_edge(i_clk) then
            current_state <= next_state;
        end if;
    end process;

    main_process: process(current_state, next_state, i_start, i_data, o_address_cur, o_address_next, o_address_r, o_address_w, 
    cfr_pixel, temp_pixel_value, current_pixel_value, max_pixel, new_pixel_value, min_pixel, delta_value, shift_level, n_col, n_riga)
    begin
      case (current_state) is
        when RST=>
            o_en <= '0';
            o_we <= '0';
            o_done <= '0';
           
            o_address <= "0000000000000000";
            o_address_next <= "0000000000000000";
            o_address_r <= "0000000000000010";
            o_address_w <= "0000000000000000";
            o_address_cur <= "0000000000000000";
            o_data <= "00000000";  
            min_pixel <= "11111111";
            max_pixel <= "00000000";
            delta_value <= "00000000";
            temp_pixel_value <= "0000000000000000";
            new_pixel_value <= "00000000";
            current_pixel_value <= "00000000";
            n_col <= 0;
            n_riga <= 0;
            shift_level <= 0;

            next_state <= START;
        
        when START => 
            o_en <= '1'; 
            o_we <= '0';
            if(i_start = '1') then
                next_state <= COLONNE;
            end if;

        when COLONNE => 
            o_en <= '0';
            o_we <= '0';
            n_col <= TO_INTEGER(unsigned(i_data));
            o_address_next <= std_logic_vector(unsigned(o_address_cur) + 1);

            next_state <= SET_ADD1;

        when SET_ADD1 =>
            o_en <= '1';
            o_we <= '0';
            o_address <= o_address_next;
            o_address_cur <= o_address_next;    
            
            next_state <= RIGHE;

        when RIGHE =>
            o_en <= '0';
            o_we <= '0';
            n_riga <= TO_INTEGER(unsigned(i_data));
            o_address_next <= std_logic_vector(unsigned(o_address_cur) + 1);  

            next_state <= SET_ADD2;

        when SET_ADD2 =>
            if(n_col = 0) or (n_riga = 0) then
            o_en <= '0';
            o_we <= '0';
            next_state <= DONE;
            else
            o_en <= '1';
            o_we <= '0';
            o_address_r <= "0000000000000010";
            o_address_w <= std_logic_vector(TO_UNSIGNED(2 + n_riga*n_col,16));
            o_address <= o_address_next;
            o_address_cur <= o_address_next;
            next_state <= CFR;  
            end if;
            
        when CFR =>
            o_en <= '0';
            o_we <= '0';

            o_address_next <= std_logic_vector(unsigned(o_address_cur) + 1);
            cfr_pixel <= unsigned(i_data); 
            
            next_state <= SET_IMG;
        
        when SET_IMG =>
            o_en <= '0';
            o_we <= '0';
            
            if(max_pixel < cfr_pixel) then
                max_pixel <= cfr_pixel;
            end if;    
            if(min_pixel > cfr_pixel) then
                min_pixel <= cfr_pixel;
            end if;        

                if(o_address_cur = std_logic_vector(TO_UNSIGNED(n_col*n_riga,16) + 1)) then
                    next_state <= DELTA;
                else 
                    next_state <= SET_ADD3;
                end if;
        
        when SET_ADD3 =>
            o_en <= '1';
            o_we <= '0';
            o_address <= o_address_next;
            o_address_cur <= o_address_next;
        next_state <= CFR;

        when DELTA =>
            o_en <= '0';
            o_we <= '0';

            delta_value <= max_pixel - min_pixel;

        next_state <= SETUP_VALUES;

        when SETUP_VALUES =>
            o_en <= '1';
            o_we <= '0';
            o_address <= o_address_r;
            o_address_cur <= o_address_r;

            if delta_value = 0 then shift_level <= 8;
            elsif (delta_value >= 1) and (delta_value <=2) then shift_level <= 7;
            elsif (delta_value >= 3) and (delta_value <= 6) then shift_level <= 6;
            elsif (delta_value >= 7) and (delta_value <= 14) then shift_level <= 5;
            elsif (delta_value >= 15) and (delta_value <= 30) then shift_level <= 4;
            elsif (delta_value >= 31) and (delta_value <= 62) then shift_level <= 3;
            elsif (delta_value >= 63) and (delta_value <= 126) then shift_level <= 2;
            elsif (delta_value >= 127) and (delta_value <= 254) then shift_level <= 1;
            elsif (delta_value = 255) then shift_level <= 0;
            end if;

            next_state <= READ_STATE;
    
        when READ_STATE =>
            o_en <= '0';
            o_we <= '0';
          
            o_address_r <= std_logic_vector(unsigned(o_address_cur) + 1);
            current_pixel_value <= unsigned(i_data);
            
        next_state <= WRITE_SAVE;
        
        when WRITE_SAVE =>
            o_en <= '0';
            o_we <= '0';
            o_address <= o_address_w;
            o_address_cur <= o_address_w;
            next_state <= SHIFT;
            
        when SHIFT => 
            o_en <= '0';
            o_we <= '0';

            temp_pixel_value <= shift_left(RESIZE((current_pixel_value - min_pixel),16), shift_level);

        next_state <= NEW_PIXEL;

        when NEW_PIXEL =>
            o_en <= '1';
            o_we <= '1';

            if(temp_pixel_value<255) then
            new_pixel_value <= RESIZE(unsigned(temp_pixel_value),8);
            else 
            new_pixel_value <= "11111111";
            end if;
            
            o_address_w <= std_logic_vector(unsigned(o_address_cur) + 1);
            o_data <= std_logic_vector(new_pixel_value); 
            
        next_state <= READ_SAVE;

        when READ_SAVE =>            
            o_en <= '1';
            o_we <= '0';
            o_address <= o_address_r;
            o_address_cur <= o_address_r;
                       
            if(o_address_r = std_logic_vector(TO_UNSIGNED(n_col*n_riga,16) + 2)) then
                o_en <= '0';
                o_we <= '0';
                next_state <= DONE;
            else
                next_state <= READ_STATE;
            end if;

        when DONE =>
            o_en <= '0';
            o_we <= '0';
            o_done <= '1';

            if(i_start = '0') then
            next_state <= RST;
            end if;
        end case;
    end process;
end FSM; 
