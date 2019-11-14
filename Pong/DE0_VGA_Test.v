//	DE0_VGA_Test.v
//	Author: Parker Dillmann
//	Website: http://www.longhornengineer.com
// Github: https://github.com/LonghornEngineer

// Extended by Adrian Reimer

`define SCREEN_WIDTH 1280
`define SCREEN_HEIGHT 1024
`define TRANSLATION_DELAY 600000
`define POINTS_REFRESH_DELAY 200000000
`define BACKGROUND_COLOR 12'b1111_1111_1111
`define OBJECT_COLOR 12'b0000_0000_0000

module DE0_VGA_Test 
(
	 clk_50, INPUT_SWS, INPUT_BTN, VGA_BUS_R, VGA_BUS_G, VGA_BUS_B, VGA_HS, VGA_VS, HEX0_D, HEX1_D, LEDG
);

input		wire				clk_50;

input		wire	[9:0]		INPUT_SWS;
input		wire	[2:0]		INPUT_BTN;

output	reg	[3:0]		VGA_BUS_R;		//Output Red
output	reg	[3:0]		VGA_BUS_G;		//Output Green
output	reg	[3:0]		VGA_BUS_B;		//Output Blue

output	reg	[0:0]		VGA_HS;			//Horizontal Sync
output	reg	[0:0]		VGA_VS;			//Vertical Sync

output 	reg 	[6:0]		HEX0_D;			// 7 Segment 
output 	reg 	[6:0]		HEX1_D;			// -	

output 	reg 	[9:0]		LEDG;				// green leds

			reg	[10:0]	X_pix;			//Location in X of the driver
			reg	[10:0]	Y_pix;			//Location in Y of the driver
			
			reg	[0:0]		H_visible;		//H_blank?
			reg	[0:0]		V_visible;		//V_blank?
			
			wire	[0:0]		pixel_clk;		//Pixel clock. Every clock a pixel is being drawn. 
			reg	[9:0]		pixel_cnt;		//How many pixels have been output.
			
			reg	[11:0]	pixel_color;	//Input to driver. 
			
			reg	[16:0]	p1_x_max; 		// Player 1 Box
			reg	[16:0]	p1_x_min; 		// -
			reg	[16:0]	p1_y_max; 		// -
			reg	[16:0]	p1_y_min; 		// -
			
			reg	[16:0]	p2_x_max; 		// Player 2 Box
			reg	[16:0]	p2_x_min; 		// -
			reg	[16:0]	p2_y_max; 		// -
			reg	[16:0]	p2_y_min; 		// -
			
			reg	[16:0]	ball_x_max; 	// Ball Box
			reg	[16:0]	ball_x_min; 	// -
			reg	[16:0]	ball_y_max; 	// -
			reg	[16:0]	ball_y_min; 	// -
			
			reg 	[31:0]	p1_score;		// Player 1 Score
			reg 	[31:0]	p2_score;		// Player 2 Score
			
			reg	[31:0]	translation_delay; // delay for updating movement
			reg 	[31:0] 	points_refresh_delay; // delay for refreshing and cycling points 
			
			reg 	[0:0] 	last_points_was_p1; // did we display Player 1 Points last time ?
			reg 	[0:0] 	last_collision_with_bottom; // did ball collide last time with bottom end ?
			reg 	[0:0] 	last_collision_with_left; // did ball collide last time with left end / Player Box ?
			
			
initial
	begin
		pixel_color <= `BACKGROUND_COLOR; // white screen
		p1_x_max <= 20; // Player 1 start Position
		p1_x_min <= 0; // -
		p1_y_max <= 600; // -
		p1_y_min <= 500; // - 	
		
		p2_x_max <= 1280; // Player 2 start Position
		p2_x_min <= 1260; // -
		p2_y_max <= 600; // -
		p2_y_min <= 500; // -
		
		ball_x_max <= 550; // Ball start Position
		ball_x_min <= 500; // -
		ball_y_max <= 600; // -
		ball_y_min <= 550; // -
		
		p1_score <= 0; // Player 1 start Score
		p2_score <= 0; // Player 2 start Score
		
		HEX0_D <= 7'b1111_001; // Display Player number (1 or 2)
		HEX1_D <= 7'b0001_100; // Display P
		
		LEDG <= 0; // leds start off
		
		translation_delay <= `TRANSLATION_DELAY; // dependent on pixel clock cycles
		points_refresh_delay <= `POINTS_REFRESH_DELAY; // -
		
		last_points_was_p1 <= 0; // we start to display player 1 points
		last_collision_with_bottom <= 0; // Ball starts with (-1,-1) vector
		last_collision_with_left <= 0; // -
	end
	
	
always @(posedge pixel_clk)
	begin
		// ### Points Display
		points_refresh_delay <= points_refresh_delay - 1;
		if(points_refresh_delay <= 0)
			begin
				if(last_points_was_p1)
					begin
						// Display Player 2 Points
						last_points_was_p1 <= 0;
						HEX0_D <= 7'b0100_100;
						LEDG <= p2_score;
					end
				else
					begin
						// Display Player 1 Points
						last_points_was_p1 <= 1;
						HEX0_D <= 7'b1111_001;
						LEDG <= p1_score;
					end
				points_refresh_delay <= `POINTS_REFRESH_DELAY; // set delay back to default
			end
	end
				
	
always @(posedge pixel_clk)
	begin	
		translation_delay <= translation_delay - 1;
		if(translation_delay <= 0)
			begin
			// ### ball translation
			if(ball_y_min <= 0) // ball hit bottom screen
				begin
					last_collision_with_bottom <= 1;
				end
			else if(ball_y_max >= `SCREEN_HEIGHT) // ball hit top screen
				begin
					last_collision_with_bottom <= 0;
				end
			if(ball_x_min <= 0) // ball hit left screen
				begin
					last_collision_with_left <= 1;
					ball_x_max += 500;
					ball_x_min += 500;
					p2_score += 1; // Add point to Player 2
				end
			else if(ball_x_max >= `SCREEN_WIDTH) // ball hit right screen
				begin
					last_collision_with_left <= 0;
					ball_x_max -= 500;
					ball_x_min -= 500;
					p1_score += 1; // Add point to Player 1
				end
			if((ball_x_min <= p1_x_max) && (ball_y_min <= p1_y_max) && (ball_y_max >= p1_y_min)) // ball hit Player 1
				begin
					last_collision_with_left <= 1;
				end
			else if((ball_x_max >= p2_x_min) && (ball_y_min <= p2_y_max) && (ball_y_max >= p2_y_min)) // ball hit Player 2
				begin
					last_collision_with_left <= 0;
				end
			if(last_collision_with_bottom)
				begin
					ball_y_max += 1;
					ball_y_min += 1;
				end
			else
				begin
					ball_y_max -= 1;
					ball_y_min -= 1;
				end
			if(last_collision_with_left)
				begin
					ball_x_max += 1;
					ball_x_min += 1;
				end
			else
				begin
					ball_x_max -= 1;
					ball_x_min -= 1;
				end
			// ### Player 1 translation
			casex (INPUT_SWS)
			10'bxxxx_xxxx_01:
				begin
					if(p1_y_max < `SCREEN_HEIGHT) // Player 1 did NOT reach Top Screen
						begin
							p1_y_max += 1;
							p1_y_min += 1;
						end
				end
			endcase
			casex (INPUT_SWS) // Player 1 did NOT reach Bottom Screen
			10'bxxxx_xxxx_10:
				begin
					if(p1_y_min > 0)
						begin
							p1_y_max -= 1;
							p1_y_min -= 1;
						end
				end
			endcase
			// ### Player 2 translation
			casex (INPUT_SWS) // Player 2 did NOT reach Bottom Screen
			10'b10xx_xxxx_xx:
				begin
					if(p2_y_min > 0)
						begin
							p2_y_max -= 1;
							p2_y_min -= 1;
						end
				end
			endcase
			casex (INPUT_SWS) // Player 2 did NOT reach Top Screen
			10'b01xx_xxxx_xx:
				begin
					if(p2_y_max < `SCREEN_HEIGHT)
						begin
							p2_y_max += 1;
							p2_y_min += 1;
						end
				end
			endcase
			translation_delay <= `TRANSLATION_DELAY; // set delay back to default
		end
	end
	
always @(posedge pixel_clk)
	begin		
		// ### Draw
		if((X_pix < p1_x_max && X_pix > p1_x_min && Y_pix < p1_y_max && Y_pix > p1_y_min) 
			|| (X_pix < p2_x_max && X_pix > p2_x_min && Y_pix < p2_y_max && Y_pix > p2_y_min)
			|| (X_pix < ball_x_max && X_pix > ball_x_min && Y_pix < ball_y_max && Y_pix > ball_y_min)) // set Pickel to White Color, if Pickel is in (Player1Box/Player2Box/BallBox)
			begin
				pixel_color <= `OBJECT_COLOR;
			end
		else // set Pixel to White
			pixel_color <= `BACKGROUND_COLOR;	
	end
						
			
		DE0_VGA VGA_Driver
		(
			.clk_50(clk_50),
			.pixel_color(pixel_color),
			.VGA_BUS_R(VGA_BUS_R), 
			.VGA_BUS_G(VGA_BUS_G), 
			.VGA_BUS_B(VGA_BUS_B), 
			.VGA_HS(VGA_HS), 
			.VGA_VS(VGA_VS), 
			.X_pix(X_pix), 
			.Y_pix(Y_pix), 
			.H_visible(H_visible),
			.V_visible(V_visible), 
			.pixel_clk(pixel_clk),
			.pixel_cnt(pixel_cnt)
		);
		
endmodule