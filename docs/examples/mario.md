# New Book

```julia (editor=true, logging=false, output=true)

```
```julia (editor=true, logging=false, output=true)
# 🌟 Stunning 3D Torus Knot

using WGLMakie

# Create beautiful 3D parametric surface (torus knot)
u = range(0, 2π, length=100)
v = range(0, 2π, length=50)

p, q = 3, 2  # Torus knot parameters for (3,2) trefoil knot
R, r = 3, 1  # Major and minor radii

# Parametric equations for 3D torus knot
x = [(R + r * cos(q * vi)) * cos(p * ui) for ui in u, vi in v]
y = [(R + r * cos(q * vi)) * sin(p * ui) for ui in u, vi in v]
z = [r * sin(q * vi) for ui in u, vi in v]

# Create stunning 3D visualization
fig = Figure(size=(700, 600), backgroundcolor=:black)
ax = Axis3(fig[1, 1], 
    title="3D Torus Knot",
    xlabel="X", ylabel="Y", zlabel="Z",
    backgroundcolor=:black
)

# Beautiful iridescent surface
surface!(ax, x, y, z, colormap=:rainbow, shading=true, alpha=0.9)

# Add delicate wireframe for mathematical structure
wireframe!(ax, x, y, z, color=(:white, 0.3), linewidth=0.5)

fig
```
```julia (editor=true, logging=false, output=true)
# 🎨 Elegant Interactive Dashboard

using WGLMakie, Bonito

function create_elegant_dashboard()
    # Beautiful styled sliders
    resolution_slider = StylableSlider(50:25:300, value=150, 
                                     slider_height=20, thumb_width=20, thumb_height=20)
    
    frequency_slider = StylableSlider(0.5:0.1:4.0, value=1.5,
                                    slider_height=20, thumb_width=20, thumb_height=20)
    
    amplitude_slider = StylableSlider(0.2:0.1:2.0, value=1.0,
                                    slider_height=20, thumb_width=20, thumb_height=20)
    
    # Create figure ONCE (no observables of figures!)
    fig = Figure(size=(600, 400))
    ax = Axis(fig[1, 1], 
        title="Beautiful Function Explorer",
        xlabel="x", ylabel="y"
    )
    
    # Initial data and plots
    x = range(0, 8π, length=150)
    y1 = sin.(1.5 * x)
    y2 = 0.5 * cos.(2.0 * x)
    
    line1 = lines!(ax, Point2f.(x, y1), color=:blue, linewidth=3, label="Primary")
    line2 = lines!(ax, Point2f.(x, y2), color=:red, linewidth=2, label="Secondary")
    axislegend(ax, position=:rt)
    ylims!(ax, -2.5, 2.5)
    
    # Update existing plots when sliders change
    on(resolution_slider.value) do n
        freq = frequency_slider.value[]
        amp = amplitude_slider.value[]
        
        x_new = range(0, 8π, length=n)
        y1_new = amp * sin.(freq * x_new)
        y2_new = 0.5 * amp * cos.(2 * freq * x_new)
        
        line1[1] = Point2f.(x_new, y1_new)
        line2[1] = Point2f.(x_new, y2_new)
        ax.title = "Resolution: $n, Frequency: $(round(freq, digits=1)), Amplitude: $(round(amp, digits=1))"
    end
    
    on(frequency_slider.value) do freq
        n = resolution_slider.value[]
        amp = amplitude_slider.value[]
        
        x_new = range(0, 8π, length=n)
        y1_new = amp * sin.(freq * x_new)
        y2_new = 0.5 * amp * cos.(2 * freq * x_new)
        
        line1[1] = Point2f.(x_new, y1_new)
        line2[1] = Point2f.(x_new, y2_new)
        ax.title = "Resolution: $n, Frequency: $(round(freq, digits=1)), Amplitude: $(round(amp, digits=1))"
    end
    
    on(amplitude_slider.value) do amp
        n = resolution_slider.value[]
        freq = frequency_slider.value[]
        
        x_new = range(0, 8π, length=n)
        y1_new = amp * sin.(freq * x_new)
        y2_new = 0.5 * amp * cos.(2 * freq * x_new)
        
        line1[1] = Point2f.(x_new, y1_new)
        line2[1] = Point2f.(x_new, y2_new)
        ax.title = "Resolution: $n, Frequency: $(round(freq, digits=1)), Amplitude: $(round(amp, digits=1))"
    end
    
    # Gorgeous layout with styled cards and professional design
    control_panel = Card(
        Col(
            DOM.div(
                DOM.h2("🎛️ Function Controls", 
                      style="color: #2c3e50; margin: 0 0 25px 0; text-align: center; font-family: 'Segoe UI', sans-serif;"),
                style="border-bottom: 3px solid #3498db; padding-bottom: 15px; margin-bottom: 20px;"
            ),
            
            Card(
                Labeled("📊 Resolution", resolution_slider, 
                       label_style=Styles("font-weight" => "bold", "color" => "#2980b9", "font-size" => "16px")),
                backgroundcolor=(:lightblue, 0.1), margin="8px", border_radius="10px"
            ),
            
            Card(
                Labeled("🌊 Frequency", frequency_slider, 
                       label_style=Styles("font-weight" => "bold", "color" => "#e67e22", "font-size" => "16px")),
                backgroundcolor=(:orange, 0.1), margin="8px", border_radius="10px"
            ),
            
            Card(
                Labeled("📈 Amplitude", amplitude_slider, 
                       label_style=Styles("font-weight" => "bold", "color" => "#8e44ad", "font-size" => "16px")),
                backgroundcolor=(:purple, 0.1), margin="8px", border_radius="10px"
            )
        ),
        backgroundcolor=(:white, 0.95),
        shadow_size="0 10px 30px",
        shadow_color=(:black, 0.15),
        border_radius="20px",
        padding="30px"
    )
    
    return Row(control_panel, fig)
end

# Display the elegant dashboard
dashboard = create_elegant_dashboard()
dashboard
```
