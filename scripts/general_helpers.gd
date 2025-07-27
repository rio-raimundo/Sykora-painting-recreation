extends Node2D

# --- HELPER FUNCTIONS ---
static func sum(array):
	var x = 0.0
	for element in array: x += element
	return x

func weighted_random(probabilities: Array):
	# Treat the sum of the probabilities as an upper bound and check where we got 
	var rnd_guess = randf() * sum(probabilities)

	for i in range(len(probabilities)):
		if rnd_guess < probabilities[i]:
			return i
		rnd_guess -= probabilities[i]

func rotate_by(point: Vector2, angle: float, centre: Vector2 = Vector2(0,0)):
	return centre + (point-centre).rotated(angle)

# Converts a boolean integer to either black or white
func to_color(x: bool):
	if x == true: return Color(1,1,1)
	if x == false: return Color(0,0,0)
	return null