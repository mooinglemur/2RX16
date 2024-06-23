import pygame
import sys

def polygon_to_pixel_lines(polygon):
    lines = []
    for i in range(len(polygon)):
        x1, y1 = polygon[i]
        x2, y2 = polygon[(i + 1) % len(polygon)]
        if y1 == y2:  # Horizontal line
            lines.append((y1, min(x1, x2), max(x1, x2)))
        elif y1 < y2:  # Line goes upwards
            for y in range(y1, y2 + 1):
                x = x1 + (x2 - x1) * (y - y1) / (y2 - y1)
                lines.append((y, x, x))
        else:  # Line goes downwards
            for y in range(y2, y1 + 1):
                x = x2 + (x1 - x2) * (y - y2) / (y1 - y2)
                lines.append((y, x, x))
    return lines

# Example polygon coordinates
polygon = [(100, 100), (300, 200), (400, 400), (200, 300)]

# Initialize Pygame
pygame.init()

# Set up the display
width, height = 500, 500
screen = pygame.display.set_mode((width, height))
pygame.display.set_caption("Polygon to Pixel Lines")

# Convert polygon to pixel lines
pixel_lines = polygon_to_pixel_lines(polygon)

# Main loop
while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit()
            sys.exit()

    # Clear the screen
    screen.fill((255, 255, 255))

    # Draw pixel lines
    for y, x1, x2 in pixel_lines:
        pygame.draw.line(screen, (0, 0, 0), (x1, y), (x2, y))

    # Update the display
    pygame.display.flip()
