----------------------------------------------------------------------------------
-- Politecnico Di Milano
-- Andrea Lampis
-- Matricola 888390
-- Codice Persona 10622804
-- Prova Finale Di Reti Logiche 2020
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;

--------------------------------------------------------------------------------------------
-- Entity Progetto Reti Logiche
--------------------------------------------------------------------------------------------

entity project_reti_logiche is
  port (
            i_clk       :   in      std_logic;                      -- tb_clk           /   segnale di CLOCK in ingresso generato dal TestBench
            i_start     :   in      std_logic;                      -- tb_start         /   segnale di START generato dal TestBench
            i_rst       :   in      std_logic;                      -- tb_rst           /   segnale di RESET che inizializza la macchina pronta per ricevere il primo segnale START
            i_data      :   in      std_logic_vector(7 downto 0);   -- mem_o_data       /   segnale (vettore) che arriva dalla memoria in seguito ad una richiesta di lettura
            o_address   :   out     std_logic_vector(15 downto 0);  -- mem_address      /   segnale (vettore) di uscita che manda l'indirizzo alla memoria
            o_done      :   out     std_logic;                      -- tb_done          /   segnale di uscita che comunica la fine dell'elaborazione e il dato di uscita scritto in memoria
            o_en        :   out     std_logic;                      -- enable_wire      /   segnale di ENABLE da dover mandare alla memoria per comunicare (sia in lettura che in scrittura)
            o_we        :   out     std_logic;                      -- mem_we           /   segnale di WRITE ENABLE da dover mandare alla memoria (=1) per poter scriverci. Per leggere da memoria deve essere =0
            o_data      :   out     std_logic_vector(7 downto 0)    -- mem_i_data       /   segnale (vettore) di uscita dal componente verso la memora
        );
end project_reti_logiche;

--------------------------------------------------------------------------------------------
-- Architecture Progetto Reti Logiche
--------------------------------------------------------------------------------------------

architecture Behavioral of project_reti_logiche is

--------------------------------------------------------------------------------------------
-- Definizione Type -- Rappresentano gli stati della FSM
--------------------------------------------------------------------------------------------
type state_type is (RESET_STATE,      -- Stato di reset della FSM
                    START_STATE,      -- Stato iniziale della FSM
                    WAIT_STATE,       -- Stato di attesa per il corretto caricamento dei dati in memoria
                    READADDR_STATE,   -- Stato nel quale avviene la lettura dell'indirizzo da codificare
                    WZ_R_STATE,       -- Stato nel quale viene richiesta la Working Zone desiderata (incrementato con un contatore)
                    WZ_W_STATE,       -- Stato nel quale si riceve il dato contenuto nella WZ richiesta. Se necessario, effettua la codifica
                    WRITE_STATE,      -- Stato nel quale viene scritto in uscita l'indirizzo codificato
                    DONE1_STATE,      -- Stato nel quale viene segnalato il termine della codifica
                    DONE0_STATE);     -- Stato nel quale ci si trova al termine della codifica. La FSM è pronta per iniziare una nuova codifica
signal state : state_type;

type p_state_type is (START_STATE, WZ_R_STATE); -- previous_state_type: utilizzati quando è necessario aspettare un ciclo di clock
signal p_state : p_state_type;

begin

state_reg: process(i_clk, i_rst)

  --------------------------------------------------------------------------------------------
  -- Variabili Utilizzate
  --------------------------------------------------------------------------------------------
  variable count : integer range 0 to 7 := 0;         -- memorizza lo stato di avanzamento delle WZ
  variable addr : integer range 0 to 127;             -- memorizza l'indirizzo da codificare
  variable offset : integer range 0 to 3 := 0;        -- memorizza (come intero) l'offset dell'indirizzo codificato
  variable WZ_offset : std_logic_vector(3 downto 0);  -- memorizza (come vettore) l'offset dell'indirizzo codificato
  variable WZ_num : std_logic_vector(2 downto 0);     -- memorizza (come vettore) il numero della WZ di appartenenza dell'indirizzo da codificare
  variable i_data_int : integer range 0 to 127;       -- memorizza (come intero) il valore letto dalla WZ corrente
  
  --------------------------------------------------------------------------------------------
  -- Logica FSM
  --------------------------------------------------------------------------------------------
  begin
    if i_rst='1' then -- Arriva segnale di reset
      state <= RESET_STATE;
      o_en <= '0';
      o_we <= '0';
      o_done <= '0';
      count := 0;
      
    elsif rising_edge(i_clk) then -- Se è trascorso un ciclo di clock e sono sul fronte di salita
    
      case state is
      
        when RESET_STATE =>
          --report "** RESET **";
          if i_rst = '0' and i_start = '1' then
            state <= START_STATE;
          else
            state <= RESET_STATE;
          end if;
          
        when START_STATE =>
          --report "** START **";
          o_en <= '1'; -- attivo la comunicazione con la memoria
          o_we <= '0'; -- mi assicuro che sia disabilitata la scrittura in memoria
          count := 0;  -- mi assicuro che il contatore sia a 0
          o_address <= std_logic_vector(to_unsigned(8 , 16)); -- richiedo il primo dato che mi serve dalla memoria: è l'indirizzo da codificare
          p_state <= START_STATE;
          state <= WAIT_STATE;
          
       when WAIT_STATE => -- attendo un colpo di clock
          case p_state is   
            when START_STATE =>
                state <= READADDR_STATE;
            when WZ_R_STATE =>
                state <= WZ_W_STATE;
          end case;
          
        when READADDR_STATE =>
          addr := to_integer(unsigned(i_data)); -- leggo il dato richiesto e lo converto da intero. E' l'indirizzo da codificare
          --report "** READ ADDR: " & integer'image(addr) & " **";
          state <= WZ_R_STATE;
          
        when WZ_R_STATE =>
          o_address <= std_logic_vector(to_unsigned(count , 16)); -- richiedo progressivamente la lettura della WZ
          --report "** READ WZ " & integer'image(count) & " **";
          p_state <= WZ_R_STATE;
          state <= WAIT_STATE;
          
        when WZ_W_STATE =>
          --report "** WRITE WZ " & integer'image(count) & " : " & integer'image(to_integer(unsigned(i_data))) & " **";
          
          i_data_int := to_integer(unsigned(i_data));            -- ricevo il dato contenuto nella WZ richiesta
          if (addr >= i_data_int) and (addr < i_data_int+4) then -- SE l'inidirizzo da codificare appartiene alla WZ corrente effettuo la codifica e passo alla scrittura in uscita
            offset := (addr - i_data_int);                        -- calcolo l'offset
            WZ_num := std_logic_vector(to_unsigned(count, 3));    -- converto il numero della WZ corrente da intero a vettore logico
            WZ_offset := (others => '0');                         -- codifica one-hot sintetizzabile
            WZ_offset(offset) := '1';                             -- codifica one-hot sintetizzabile
            o_data <= '1' & WZ_num & WZ_offset;                   -- creo l'indirizzo codificato nel formato richiesto e lo metto sul segnale di uscita
            o_address <= std_logic_vector(to_unsigned(9 , 16));   -- indico l'indirizzo nel quale scrivere il dato appena codificato
            --report "** WRITE RAM(9) ADDR IN WZ **";
            state <= WRITE_STATE;                                 -- passo alla scrittura in memoria
            
          elsif count = 7 then                                   -- SE l'indirizzo da codificare non appartiene a nessuna WZ, lo riscrivo in uscita così com'era
            o_data <= std_logic_vector(to_unsigned(addr, 8));
            o_address <= std_logic_vector(to_unsigned(9 , 16));
            --report "** WRITE RAM(9) ADDR OUT WZ **";
            state <= WRITE_STATE;
            
          else
              count := (count + 1);                              -- ALTRIMENTI passo alla WZ successiva
              state <= WZ_R_STATE;
          end if;

        
        when WRITE_STATE =>
          o_en <= '1';                -- mi assicuro che la comunicazione con la memoria sia attivata
          o_we <= '1';                -- attivo la scrittura in memoria
          --report "** WRITE RAM(9) **";
          state <= DONE1_STATE;

        when DONE1_STATE =>           -- a questo punto il dato è stato scritto in memoria. Segnalo che ho finito il processo di conversione
          --report "** DONE 1 **";
          o_done <= '1';
          o_en <= '0';
          o_we <= '0';
          if i_start = '0' then       -- SE lo start viene riportato a 0
              state <= DONE0_STATE;   
          else                        -- ALTRIMENTI rimango in questo stato
              state <= DONE1_STATE; 
          end if;
          
        when DONE0_STATE =>
          --report "** DONE 0 **";
          o_done <= '0';              -- ora posso inziare nuovamente il processo, se richiesto
          if i_start = '1' then
              state <= START_STATE;   
          else
              state <= DONE0_STATE;
          end if;
          
        when others =>
          state <= state;
            
      end case;
    end if;
  end process;


end Behavioral;
