module SCU_DSP (
	input             CLK,
	input             RST_N,
	input             CE,
	
	input             CE_R,
	input             CE_F,
	input       [1:0] A,
	input      [31:0] DI,
	output reg [31:0] DO,
	input       [3:0] WE,
	input             RE,
	
	output     [31:0] DSO,
	output            RA0W,
	output            WA0W,
	output            DMAW,
	
	input      [31:0] DMA_DI,
	output     [31:0] DMA_DO,
	output            DMA_WE,
	output reg        DMA_REQ,
	input             DMA_ACK,
	output            DMA_RUN,
	output            DMA_LAST,
	input             DMA_END,
	
	output            IRQ,
	output DecInst_t  DBG_DECI,
	output     [47:0] DBG_Q,
	output     [47:0] DBG_AC,
	output     [47:0] DBG_P,
	output reg        HOOK1,
	output reg        HOOK2
);
	
	import SCUDSP_PKG::*;

	//Registers
	ALUReg_t   AC;
	ALUReg_t   P;
	bit [31:0] RX;
	bit [31:0] RY;
	bit  [7:0] PC;
	bit [11:0] LOP;
	bit  [7:0] TOP;
	bit  [5:0] CT0;
	bit  [5:0] CT1;
	bit  [5:0] CT2;
	bit  [5:0] CT3;
	bit  [7:0] TN0;
	bit        T0;
	bit        EX;
	bit        EP; 
	bit        PR;
	bit        ES;
	bit        LE;
	bit        E;
	bit        S;
	bit        Z;
	bit        C;
	bit        V;

	bit  [5:0] DATA_RAM_ADDR [4];
	bit [31:0] DATA_RAM_D [4];
	bit        DATA_RAM_WE [4];
	bit [31:0] DATA_RAM_Q [4];
	
	bit  [7:0] PRG_RAM_ADDR;
	bit [31:0] PRG_RAM_D;
	bit        PRG_RAM_WE;
	bit [31:0] PRG_RAM_Q;
	
	bit  [7:0] DATA_TRANS_ADDR;
//	bit        PRG_TRANS_AS;
	bit        PRG_TRANS_WE;
	bit  [7:0] PRG_TRANS_ADDR;
	bit        DATA_TRANS_WE;
	bit        DATA_TRANS_RE;
	
	wire DMA_CE = T0 && DMA_ACK;
	wire RUN = (EX || ES) && ~T0;

	
	reg [31:0] IC;
	DecInst_t DECI;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			IC <= '0;
		end else if (CE) begin
			if (!EX) begin
				IC <= '0;
			end 
			if (RUN) begin
				IC <= PRG_RAM_Q;
			end
		end
	end
	
	wire COND = IC[24] ? ((IC[22]&T0) | (IC[21]&C) | (IC[20]&S) | (IC[19]&Z)) : ((~IC[22]|~T0) & (~IC[21]|~C) & (~IC[20]|~S) & (~IC[19]|~Z));
	assign DECI = Decode(IC, COND);
	assign DBG_DECI = DECI;
	
	DMAInst_t  DMAI;
	
	
	//ALU
	ALUReg_t   ALU_Q;
	bit        ALU_C;
	always_comb begin
		{ALU_C,ALU_Q} = {1'b0,AC};
		case (IC[29:26])
			4'b0001: {ALU_C,ALU_Q.L} = {1'b0,AC.L} & {1'b0,P.L};
			4'b0010: {ALU_C,ALU_Q.L} = {1'b0,AC.L} | {1'b0,P.L};
			4'b0011: {ALU_C,ALU_Q.L} = {1'b0,AC.L} ^ {1'b0,P.L};
			4'b0100: {ALU_C,ALU_Q.L} = {1'b0,AC.L} + {1'b0,P.L};
			4'b0101: {ALU_C,ALU_Q.L} = {1'b0,AC.L} - {1'b0,P.L};
			4'b0110: {ALU_C,ALU_Q  } = {1'b0,AC  } + {1'b0,P  };
			4'b1000: {ALU_Q.L,ALU_C} = {AC.L[31],AC.L};
			4'b1001: {ALU_Q.L,ALU_C} = {AC.L[0],AC.L};
			4'b1010: {ALU_C,ALU_Q.L} = {AC.L,1'b0};
			4'b1011: {ALU_C,ALU_Q.L} = {AC.L,AC.L[31]};
			4'b1111: {ALU_C,ALU_Q.L} = {AC.L[24:0],AC.L[31:24]};
			default: ;
		endcase
	end
	
	assign DBG_Q = ALU_Q;
	assign DBG_AC = AC;
	assign DBG_P = P;
	
	always @(posedge CLK or negedge RST_N) begin
		bit S31, S47, ZL, ZH;
		
		if (!RST_N) begin
			S <= 0;
			Z <= 0;
			C <= 0;
			V <= 0;
		end
		else if (RUN && CE) begin
			S31 = ALU_Q[31];
			S47 = ALU_Q[47];
			ZL = ~|ALU_Q.L;
			ZH = ~|ALU_Q.H;
			if (DECI.ALU) begin
				case (IC[29:26])
					4'b0001: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					4'b0010: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					4'b0011: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					4'b0100: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					4'b0101: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					4'b0110: begin S <= S47; Z <= ZL&ZH; C <= ALU_C; end
					4'b1000: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					4'b1001: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					4'b1010: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					4'b1011: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					4'b1111: begin S <= S31; Z <= ZL;    C <= ALU_C; end
					default:;
				endcase
				V <= 0;//TODO
			end
//			else begin
//				if (A == 2'b00 && RE) begin
//					V <= 0;
//				end
//			end
		end
	end
	
	wire [47: 0] MUL = $signed(RX) * $signed(RY);


	wire [31: 0] D0BUSI = DMA_DI;
	bit  [31: 0] D0BUSO;
	bit  [31: 0] D1BUS;
	bit  [31: 0] XBUS;
	bit  [31: 0] YBUS;
	always_comb begin
		XBUS = DATA_RAM_Q[DECI.XBUS.RAMS];
		YBUS = DATA_RAM_Q[DECI.YBUS.RAMS];
		
		if (DECI.D1BUS.IMMS) begin
			D1BUS = ImmSext(IC, DECI.D1BUS.IMMT);;
		end else if (DECI.D1BUS.ALUS) begin
			case (DECI.D1BUS.RAMS[0])
				1'b0: D1BUS = ALU_Q[47:16];//ALU HIGH
				2'b1: D1BUS = ALU_Q[31: 0];//ALU LOW
			endcase
		end else if (DECI.D1BUS.DMAW) begin
			D1BUS = IC;
		end else begin
			D1BUS = DATA_RAM_Q[DECI.D1BUS.RAMS];
		end
		
		D0BUSO = DATA_RAM_Q[DMAI.RAMS];
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			// synopsys translate_off
			RX <= '0;
			RY <= '0;
			AC <= '0;
			P <= '0;
			// synopsys translate_on
		end
		else if (RUN && CE) begin
			//X set
			if (DECI.XBUS.RXW) begin
				RX <= XBUS;
			end
			if (DECI.D1BUS.RXW) begin
				RX <= D1BUS;
			end
			
			//Y set
			if (DECI.YBUS.RYW) begin
				RY <= YBUS;
			end
			
			//AC set
			if (DECI.YBUS.ACW) begin
				case (DECI.YBUS.ACS)
					2'b01: AC <= '0;
					2'b10: AC <= ALU_Q;
					2'b11: AC <= {{16{YBUS[31]}},YBUS};
					default:;
				endcase
			end
			
			//P set
			if (DECI.XBUS.PW) begin
				if (DECI.XBUS.MULS) P <= MUL[47:0];
				else P <= {{16{XBUS[31]}},XBUS};
			end
			if (DECI.D1BUS.PW) begin
				P <= {{16{D1BUS[31]}},D1BUS};
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			// synopsys translate_off
			CT0 <= '0;
			CT1 <= '0;
			CT2 <= '0;
			CT3 <= '0;
			// synopsys translate_on
		end
		else begin
			if (RUN && CE) begin
				if (DECI.XBUS.CTI[0] || DECI.YBUS.CTI[0] || DECI.D1BUS.CTI[0] || DECI.DMA.CTI[0]) CT0 <= CT0 + 6'd1;
				if (DECI.D1BUS.CTW[0]) CT0 <= D1BUS[5:0];
				
				if (DECI.XBUS.CTI[1] || DECI.YBUS.CTI[1] || DECI.D1BUS.CTI[1] || DECI.DMA.CTI[1]) CT1 <= CT1 + 6'd1;
				if (DECI.D1BUS.CTW[1]) CT1 <= D1BUS[5:0];
				
				if (DECI.XBUS.CTI[2] || DECI.YBUS.CTI[2] || DECI.D1BUS.CTI[2] || DECI.DMA.CTI[2]) CT2 <= CT2 + 6'd1;
				if (DECI.D1BUS.CTW[2]) CT2 <= D1BUS[5:0];
				
				if (DECI.XBUS.CTI[3] || DECI.YBUS.CTI[3] || DECI.D1BUS.CTI[3] || DECI.DMA.CTI[3]) CT3 <= CT3 + 6'd1;
				if (DECI.D1BUS.CTW[3]) CT3 <= D1BUS[5:0];
			end
			
			if (DMA_CE && CE_R) begin
				if (DMAI.RAMW[0] || DMAI.RAMR[0]) CT0 <= CT0 + 6'd1;
				if (DMAI.RAMW[1] || DMAI.RAMR[1]) CT1 <= CT1 + 6'd1;
				if (DMAI.RAMW[2] || DMAI.RAMR[2]) CT2 <= CT2 + 6'd1;
				if (DMAI.RAMW[3] || DMAI.RAMR[3]) CT3 <= CT3 + 6'd1;
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			// synopsys translate_off
			PC <= '0;
			LOP <= '0;
			TOP <= '0;
			// synopsys translate_on
		end
		else begin
			if (RUN && CE) begin
				PC <= PC + 8'd1;
				if (DECI.D1BUS.PCW) begin
					PC <= D1BUS[7:0];
					TOP <= PC;
				end
				if (DECI.JPCW) begin
					PC <= IC[7:0];
				end
				if (DECI.CTL.BTM || DECI.CTL.LPS) begin
					if (LOP) begin
						LOP <= LOP - 12'd1;
						if (DECI.CTL.BTM) PC <= TOP;
						if (DECI.CTL.LPS) PC <= PC - 8'd1;//?
					end
				end
				
				if (DECI.D1BUS.LOPW) begin
					LOP <= D1BUS[11:0];
				end
				
				if (DECI.D1BUS.TOPW) begin
					TOP <= D1BUS[7:0];
				end
			end
			
			if (A == 2'b00 && WE && DI[15] && CE_R) begin
				PC <= DI[7:0];
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		bit [7:0] CNT_VAL;
		bit       DMA_END_PEND;
		
		if (!RST_N) begin
			TN0 <= '0;
			T0 <= 0;
			DMAI <= '0;
			DMA_REQ <= 0;
			DMA_END_PEND <= 0;
			
			HOOK1 <= 0;
			HOOK2 <= 0;
		end
		else begin
			if (CE) begin
				if (RUN) begin
					if (DECI.DMA.CNTM) begin
						CNT_VAL = DATA_RAM_Q[DECI.DMA.CNTS][7:0];
					end
					else begin
						CNT_VAL = IC[7:0];
					end
			
					if (DECI.DMA.ST && !T0) begin
						T0 <= 1;
						TN0 <= CNT_VAL;
						DMAI <= DECI.DMA;
						DMA_REQ <= 1;
					end
				end
				if (DMA_END_PEND) begin
					T0 <= 0;
					DMA_END_PEND <= 0;
				end
			end
			
			if (CE_F) begin
//				if (DMA_REQ && DMA_CE) DMA_REQ <= 0;
				
				if (DMA_END) begin
					DMA_END_PEND <= 1;
				end
			end 
			if (CE_R) begin
//				if (DMA_REQ) DMA_REQ <= 0;
				
				if (DMA_CE) begin
					DMA_REQ <= 0;
					TN0 <= TN0 - 8'd1;
					if (TN0 > 8'd1) begin
						DMA_REQ <= 1;
					end
					
					if (D0BUSO[31:16] != 16'h0000 && D0BUSO[31:16] != 16'hFFFF && DMAI.RAMR[3] && DMAI.DIR) HOOK1 <= 1;
					if (DMA_DI[31:16] != 16'h0000 && DMA_DI[31:16] != 16'hFFFF && (DMAI.RAMW[1] || DMAI.RAMW[2]) && !DMAI.DIR) HOOK2 <= 1;
				end
			end
		end
	end
	
	assign DMA_DO = D0BUSO;
	assign DMA_WE = DMAI.DIR;
	assign DMA_RUN = T0;
	assign DMA_LAST = (TN0 == 8'd1);
	
	assign DSO = D1BUS;
	assign RA0W = DECI.D1BUS.RA0W & RUN & CE;
	assign WA0W = DECI.D1BUS.WA0W & RUN & CE;
	assign DMAW = DECI.D1BUS.DMAW & RUN & CE;
	
	//DATA RAM
	wire DATA_TRANS_CS[4] = '{DATA_TRANS_ADDR[7:6] == 2'b00,DATA_TRANS_ADDR[7:6] == 2'b01,DATA_TRANS_ADDR[7:6] == 2'b10,DATA_TRANS_ADDR[7:6] == 2'b11};
	
	assign DATA_RAM_ADDR[0] = RUN || T0 ? CT0 : DATA_TRANS_ADDR[5:0];
	assign DATA_RAM_D[0] = T0 ? D0BUSI : RUN ? D1BUS : DI;
	assign DATA_RAM_WE[0] = T0 ? DMAI.RAMW[0] & DMA_CE & CE_R : RUN ? DECI.D1BUS.RAMW[0] & CE : DATA_TRANS_WE && DATA_TRANS_CS[0] & CE_R;
	DSP_DATA_RAM #(6,32) DATA_RAM0(CLK, DATA_RAM_ADDR[0], DATA_RAM_D[0], DATA_RAM_WE[0], DATA_RAM_Q[0]);
	
	assign DATA_RAM_ADDR[1] = RUN || T0 ? CT1 : DATA_TRANS_ADDR[5:0];
	assign DATA_RAM_D[1] = T0 ? D0BUSI : RUN ? D1BUS : DI;
	assign DATA_RAM_WE[1] = T0 ? DMAI.RAMW[1] & DMA_CE & CE_R : RUN ? DECI.D1BUS.RAMW[1] & CE : DATA_TRANS_WE && DATA_TRANS_CS[1] & CE_R ;
	DSP_DATA_RAM #(6,32) DATA_RAM1(CLK, DATA_RAM_ADDR[1], DATA_RAM_D[1], DATA_RAM_WE[1], DATA_RAM_Q[1]);
	
	assign DATA_RAM_ADDR[2] = RUN || T0 ? CT2 : DATA_TRANS_ADDR[5:0];
	assign DATA_RAM_D[2] = T0 ? D0BUSI : RUN ? D1BUS : DI;
	assign DATA_RAM_WE[2] = T0 ? DMAI.RAMW[2] & DMA_CE & CE_R : RUN ? DECI.D1BUS.RAMW[2] & CE : DATA_TRANS_WE && DATA_TRANS_CS[2] & CE_R ;
	DSP_DATA_RAM #(6,32) DATA_RAM2(CLK, DATA_RAM_ADDR[2], DATA_RAM_D[2], DATA_RAM_WE[2], DATA_RAM_Q[2]);
	
	assign DATA_RAM_ADDR[3] = RUN || T0 ? CT3 : DATA_TRANS_ADDR[5:0];
	assign DATA_RAM_D[3] = T0 ? D0BUSI : RUN ? D1BUS : DI;
	assign DATA_RAM_WE[3] = T0 ? DMAI.RAMW[3] & DMA_CE & CE_R : RUN ? DECI.D1BUS.RAMW[3] & CE : DATA_TRANS_WE && DATA_TRANS_CS[3] & CE_R ;
	DSP_DATA_RAM #(6,32) DATA_RAM3(CLK, DATA_RAM_ADDR[3], DATA_RAM_D[3], DATA_RAM_WE[3], DATA_RAM_Q[3]);
	
	//Control port
	always @(posedge CLK or negedge RST_N) begin
		bit WE_OLD;
		bit RE_OLD;
		
		if (!RST_N) begin
			EX <= 0;
			EP <= 0; 
			PR <= 0;
			ES <= 0;
			LE <= 0;
			E <= 0;
			PRG_TRANS_ADDR <= '0;
//			PRG_TRANS_AS <= 0;
			PRG_TRANS_WE <= 0;
			DATA_TRANS_ADDR <= '0;
			DATA_TRANS_WE <= 0;
			DATA_TRANS_RE <= 0;
		end else begin
			if (CE_R) begin
	//			PRG_TRANS_AS <= 0;
				PRG_TRANS_WE <= 0;
				DATA_TRANS_WE <= 0;
				if (PRG_TRANS_WE) PRG_TRANS_ADDR <= PRG_TRANS_ADDR + 8'd1;
				if (DATA_TRANS_WE) DATA_TRANS_ADDR <= DATA_TRANS_ADDR + 8'd1;
				
				WE_OLD <= |WE;
				if (WE && !WE_OLD) begin
					case (A)
						2'b00: begin
							EX <= DI[16];
							LE <= DI[15];
							PRG_TRANS_ADDR <= DI[7:0];
							if (EX && !EP && DI[25]) begin
								EP <= 1; 
								PR <= 0;
							end
							if (EX && !PR && DI[26]) begin
								PR <= 1;
								EP <= 0; 
							end
							if (!EX && DI[17]) begin
								ES <= 1;
							end
	//						PRG_TRANS_AS <= 1;
						end
						2'b01: begin
	//						PRG_TRANS_ADDR <= PRG_TRANS_ADDR + 8'd1;
							PRG_TRANS_WE <= 1;
						end
						2'b10: begin
							DATA_TRANS_ADDR <= DI[7:0];
						end
						2'b11: begin
	//						DATA_TRANS_ADDR <= DATA_TRANS_ADDR + 8'd1;
							DATA_TRANS_WE <= 1;
						end
						default:;
					endcase
				end
			end else if (CE_F) begin
				DATA_TRANS_RE <= 0;
				if (DATA_TRANS_RE) DATA_TRANS_ADDR <= DATA_TRANS_ADDR + 8'd1;
				
				RE_OLD <= RE;
				if (RE && !RE_OLD) begin
					case (A)
						2'b00: DO <= {8'h00,T0,S,Z,C,V,E,1'b0,EX,8'h00,PC};
						2'b01: DO <= '0;
						2'b10: DO <= '0;
						2'b11: begin
							DO <= DATA_RAM_Q[DATA_TRANS_ADDR[7:6]];
							DATA_TRANS_RE <= 1;
						end
						default: DO <= '0;
					endcase
					if (A == 2'b00 && E) begin
						E <= 0;
					end
				end
			end
			
			if (RUN && CE) begin
				if (ES) ES <= 0;
				
				if (DECI.CTL.END) begin
					EX <= 0;
					if (DECI.CTL.EI) E <= 1;
				end
			end
		end
	end
	
	assign IRQ = E;
	
	//PRG RAM
	assign PRG_RAM_ADDR = RUN ? PC : PRG_TRANS_ADDR;
	assign PRG_RAM_D = DI;
	assign PRG_RAM_WE = !RUN && PRG_TRANS_WE;
	DSP_PRG_RAM #(8,32," ","prg.txt") PRG_RAM(CLK, PRG_RAM_ADDR, PRG_RAM_D, PRG_RAM_WE & CE_R, PRG_RAM_Q);

	
endmodule
