# BonitoBook

Features of BonitBook

```julia false false true
using WGLMakie, Bonito

# Create sliders for different parameters  
time_slider = Components.Slider(1:360; value=1)
spiral_factor = Components.Slider(1:50; value=20) 
explosion = Components.Slider(1:100; value=50)
markersize = Components.Slider(1:100; value=30)

# Generate initial 3D galaxy data
n_points = 200
angles = LinRange(0, 4π, n_points)
radii = sqrt.(LinRange(0.1, 1, n_points)) * 8
spiral_angles = angles .+ radii * 0.3

initial_points = Point3f[]
for i in 1:n_points
    x = radii[i] * cos(spiral_angles[i]) + randn() * 0.3
    y = radii[i] * sin(spiral_angles[i]) + randn() * 0.3  
    z = randn() * 2
    push!(initial_points, Point3f(x, y, z))
end

# Create figure and scatter plot
fig = Figure(backgroundcolor=:black)
ax = LScene(fig[1, 1]; show_axis=false)
splot = scatter!(ax, initial_points; color=first.(initial_points), markersize=15, transparency=true)

# JavaScript following YOUR EXACT PATTERN
jss = js"""
console.log("Initializing Galaxy...");
$(splot).then(plots=>{
    console.log(plots);
    const scatter_plot = plots[0];
    const plot = scatter_plot.plot_object;
    const pos_buff = scatter_plot.geometry.attributes.positions_transformed_f32c.array;
    const initial_pos = [...pos_buff];
    console.log("Initial positions:", initial_pos.length);
    
    // Function to generate galaxy positions
    function generateGalaxy(timeVal, spiralVal, explosionVal) {
        console.log("generating");
        const newPos = [];
        const numPoints = initial_pos.length / 3;
        
        for (let i = 0; i < numPoints; i++) {
            const idx = i * 3;
            const x = initial_pos[idx];
            const y = initial_pos[idx + 1];
            const z = initial_pos[idx + 2];
            
            // Apply time rotation
            const angle = Math.atan2(y, x) + timeVal * 0.02;
            const radius = Math.sqrt(x*x + y*y);
            
            // Apply spiral effect
            const spiralAngle = angle + radius * spiralVal * 0.05;
            
            // Apply explosion
            const scale = explosionVal / 50;
            
            newPos.push(
                radius * Math.cos(spiralAngle) * scale,
                radius * Math.sin(spiralAngle) * scale,
                z * scale
            );
        }
        return newPos;
    }
    console.log("############")
    console.log($(time_slider.value));
    console.log($(spiral_factor.value));
    // Update positions based on time slider
    $(time_slider.value).on(time_val => {
        console.log("Time:", time_val);
        const spiral = $(spiral_factor.value).value;
        const explosion = $(explosion.value).value;
        const newPos = generateGalaxy(time_val, spiral, explosion);
        plot.update([['positions_transformed_f32c', newPos]]);
    });
    
    // Update positions based on spiral slider
    $(spiral_factor.value).on(spiral_val => {
        console.log("Spiral:", spiral_val);
        const time = $(time_slider.value).value;
        const explosion = $(explosion.value).value;
        const newPos = generateGalaxy(time, spiral_val, explosion);
        plot.update([['positions_transformed_f32c', newPos]]);
    });
    
    // Update positions based on explosion slider
    $(explosion.value).on(explosion_val => {
        console.log("Explosion:", explosion_val);
        const time = $(time_slider.value).value;
        const spiral = $(spiral_factor.value).value;
        const newPos = generateGalaxy(time, spiral, explosion_val);
        plot.update([['positions_transformed_f32c', newPos]]);
    });
    
    // Update marker size
    $(markersize.value).on(size => {
        console.log("Size:", size);
        plot.update([['quad_scale', [size, size]], ['quad_offset', [-size/2, -size/2]]]);
    });
    

});
"""

# Layout
DOM.div(
    DOM.h3("🌌 3D Galaxy Explorer", style="text-align: center; color: white; margin: 10px;"),
    DOM.div(
        style="display: flex; gap: 20px; align-items: center; justify-content: center; padding: 15px; background: #1a1a2e; border-radius: 10px; margin: 10px;",
        DOM.div([DOM.label("Time: ", style="color: white; margin-right: 5px;"), time_slider]),
        DOM.div([DOM.label("Spiral: ", style="color: white; margin-right: 5px;"), spiral_factor]),  
        DOM.div([DOM.label("Explosion: ", style="color: white; margin-right: 5px;"), explosion]),
        DOM.div([DOM.label("Size: ", style="color: white; margin-right: 5px;"), markersize])
    ),
    fig,
    jss
    
)
```
```julia true false true
slider = Components.Slider(10:100; style=Styles("margin" => "15px", "width" => "300px"))
f, ax, pl = scatter(rand(Point2f, 100), markersize=slider.value[])
sljs = js"""$(slider.value).on(value => {
    $(pl).then(plots=> {
        plots[0].plot_object.update([['quad_scale', [value, value]]]);
    });
});""" 
Centered(DOM.div(Centered(slider), f, sljs))
```
```julia true false true
]st
```
```julia true false true
for i in 1:20
    println("hi\n")
end
```
