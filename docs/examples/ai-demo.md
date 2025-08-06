# New Book

```julia (editor=true, logging=false, output=true)

```
```julia (editor=true, logging=false, output=true)
# First, let's create a beautiful 3D plot
using WGLMakie, Bonito

# Create a 3D surface plot with some mathematical function
x = range(-3, 3, length=50)
y = range(-3, 3, length=50)
z = [sin(sqrt(xi^2 + yi^2)) * exp(-0.1*sqrt(xi^2 + yi^2)) for xi in x, yi in y]

fig = Figure(size=(800, 600))
ax = Axis3(fig[1, 1], 
    title="Beautiful 3D Surface",
    xlabel="X axis", 
    ylabel="Y axis", 
    zlabel="Z axis")

surface!(ax, x, y, z, colormap=:plasma)

fig
```
```julia (editor=true, logging=false, output=true)
# Now let's create a simple but pretty dashboard
App() do
    # Create some interactive controls
    freq_slider = StylableSlider(0.1:0.1:5.0, value=1.0, 
        slider_height=25, thumb_width=25, thumb_height=25,
        track_color="#e0e0e0", thumb_color="#4a90e2")
    
    amp_slider = StylableSlider(0.1:0.1:3.0, value=1.0,
        slider_height=25, thumb_width=25, thumb_height=25,
        track_color="#e0e0e0", thumb_color="#e74c3c")
    
    phase_slider = StylableSlider(0:0.1:2π, value=0.0,
        slider_height=25, thumb_width=25, thumb_height=25,
        track_color="#e0e0e0", thumb_color="#2ecc71")
    
    # Button for randomizing
    random_btn = Button("Randomize", style=Styles(
        CSS("background-color" => "#9b59b6",
            "color" => "white",
            "border" => "none",
            "padding" => "10px 20px",
            "border-radius" => "5px",
            "cursor" => "pointer",
            "font-size" => "14px")
    ))
    
    # Create reactive plot data
    x = 0:0.1:4π
    plot_data = map(freq_slider.value, amp_slider.value, phase_slider.value) do f, a, p
        return a .* sin.(f .* x .+ p)
    end
    
    # Create the plot
    fig = Figure(size=(600, 400))
    ax = Axis(fig[1, 1], 
        title="Interactive Sine Wave",
        xlabel="X", 
        ylabel="Y",
        backgroundcolor=:white)
    
    lines!(ax, x, plot_data, color=:blue, linewidth=3)
    
    # Layout the dashboard
    controls = Card(
        Col(
            Labeled("Frequency", freq_slider, label_style=Styles(CSS("font-weight" => "bold", "margin-bottom" => "5px"))),
            Labeled("Amplitude", amp_slider, label_style=Styles(CSS("font-weight" => "bold", "margin-bottom" => "5px"))),
            Labeled("Phase", phase_slider, label_style=Styles(CSS("font-weight" => "bold", "margin-bottom" => "5px"))),
            random_btn
        ),
        backgroundcolor=RGBA(0.95, 0.95, 0.95, 1.0),
        padding="20px",
        border_radius="10px"
    )
    
    plot_card = Card(
        fig,
        backgroundcolor=RGBA(1, 1, 1, 1.0),
        padding="15px",
        border_radius="10px"
    )
    
    # Add some randomization functionality
    on(random_btn) do _
        freq_slider.value[] = rand(0.1:0.1:5.0)
        amp_slider.value[] = rand(0.1:0.1:3.0)
        phase_slider.value[] = rand(0:0.1:2π)
    end
    
    # Main layout
    Row(controls, plot_card, style=Styles(CSS("gap" => "20px", "padding" => "20px")))
end
```
