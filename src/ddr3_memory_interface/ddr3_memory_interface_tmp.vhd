--Copyright (C)2014-2025 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.12.01
--IP Version: 6.0
--Part Number: GW2A-LV18PG256C8/I7
--Device: GW2A-18
--Device Version: C
--Created Time: Sun May 31 10:24:06 2026

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component DDR3_Memory_Interface_Top
	port (
		clk: in std_logic;
		memory_clk: in std_logic;
		pll_lock: in std_logic;
		rst_n: in std_logic;
		clk_out: out std_logic;
		ddr_rst: out std_logic;
		init_calib_complete: out std_logic;
		cmd_ready: out std_logic;
		cmd: in std_logic_vector(2 downto 0);
		cmd_en: in std_logic;
		addr: in std_logic_vector(27 downto 0);
		wr_data_rdy: out std_logic;
		wr_data: in std_logic_vector(127 downto 0);
		wr_data_en: in std_logic;
		wr_data_end: in std_logic;
		wr_data_mask: in std_logic_vector(15 downto 0);
		rd_data: out std_logic_vector(127 downto 0);
		rd_data_valid: out std_logic;
		rd_data_end: out std_logic;
		sr_req: in std_logic;
		ref_req: in std_logic;
		sr_ack: out std_logic;
		ref_ack: out std_logic;
		burst: in std_logic;
		O_ddr_addr: out std_logic_vector(13 downto 0);
		O_ddr_ba: out std_logic_vector(2 downto 0);
		O_ddr_cs_n: out std_logic;
		O_ddr_ras_n: out std_logic;
		O_ddr_cas_n: out std_logic;
		O_ddr_we_n: out std_logic;
		O_ddr_clk: out std_logic;
		O_ddr_clk_n: out std_logic;
		O_ddr_cke: out std_logic;
		O_ddr_odt: out std_logic;
		O_ddr_reset_n: out std_logic;
		O_ddr_dqm: out std_logic_vector(1 downto 0);
		IO_ddr_dq: inout std_logic_vector(15 downto 0);
		IO_ddr_dqs: inout std_logic_vector(1 downto 0);
		IO_ddr_dqs_n: inout std_logic_vector(1 downto 0)
	);
end component;

your_instance_name: DDR3_Memory_Interface_Top
	port map (
		clk => clk,
		memory_clk => memory_clk,
		pll_lock => pll_lock,
		rst_n => rst_n,
		clk_out => clk_out,
		ddr_rst => ddr_rst,
		init_calib_complete => init_calib_complete,
		cmd_ready => cmd_ready,
		cmd => cmd,
		cmd_en => cmd_en,
		addr => addr,
		wr_data_rdy => wr_data_rdy,
		wr_data => wr_data,
		wr_data_en => wr_data_en,
		wr_data_end => wr_data_end,
		wr_data_mask => wr_data_mask,
		rd_data => rd_data,
		rd_data_valid => rd_data_valid,
		rd_data_end => rd_data_end,
		sr_req => sr_req,
		ref_req => ref_req,
		sr_ack => sr_ack,
		ref_ack => ref_ack,
		burst => burst,
		O_ddr_addr => O_ddr_addr,
		O_ddr_ba => O_ddr_ba,
		O_ddr_cs_n => O_ddr_cs_n,
		O_ddr_ras_n => O_ddr_ras_n,
		O_ddr_cas_n => O_ddr_cas_n,
		O_ddr_we_n => O_ddr_we_n,
		O_ddr_clk => O_ddr_clk,
		O_ddr_clk_n => O_ddr_clk_n,
		O_ddr_cke => O_ddr_cke,
		O_ddr_odt => O_ddr_odt,
		O_ddr_reset_n => O_ddr_reset_n,
		O_ddr_dqm => O_ddr_dqm,
		IO_ddr_dq => IO_ddr_dq,
		IO_ddr_dqs => IO_ddr_dqs,
		IO_ddr_dqs_n => IO_ddr_dqs_n
	);

----------Copy end-------------------
