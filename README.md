# Black-and-white structures painting recreation
- This project is an attempt at an interactive recreation of a painting by Zdeněk Sýkora as part of his [black-and-white structure](https://www.invaluable.com/auction-lot/zdenek-sykora-black-and-white-structure-screenpri-193-c-04640efbea) series.
- The painting that this project aims to recreate is not the exact one linked, but one that I saw at the Museum of Applied Arts in Cologne, Germany. 
- It is my first Godot project.

## Controls
- The rendered 'painting' consists of a grid of semicircles overlaid on alternating black and white lines. Many aspects of the painting are randomised, including the placement and thickness of the lines and the placements and rotations of the semicircles.
- The painting can be interacted with by pressing various hotkeys:
	1. Pressing `H` will toggle hiding/showing the semicircle layer.
	2. Pressing `C` will regenerate the black and white colored lines, and the colors of the shapes overlaid on them (which are always the inverse of the square behind)
	3. Pressing `P` will regenerate the semicircle pattern layer completely, but keep the layout of the black and white lines the same.
	4. When rendering the semicircle layer, patterns for each square are initially chosen at random. Then, they are 'rechosen' based only on the nearby patterns in that row. This creates 'stickiness' to the pattern generation, leading to the appearance of more higher-order structure. Pressing `S` will regenerate only this second iteration, leading to small variations in the shapes layer.
- Additionally, clicking the squares of the painting will also interact with it:
	1. Left clicking a square will cycle through each of the four patterns (more pattern combinations than this are possible, but are not present in the original painting, so I have stuck to the four used).
	2. Right clicking on a square will rotate the current pattern by 90 degrees.