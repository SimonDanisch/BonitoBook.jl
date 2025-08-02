using WGLMakie, Bonito
s1 = Components.Slider(1:100)
color_slider = Components.Slider(LinRange(0, 1, 100))
markersize = Components.Slider(1:100)

fig, ax, splot = scatter(1:4)
# with the above, we can find out that the positions are stored in `offset`
# (*sigh*, this is because threejs special cases `position` attributes so it can't be used)
# Now, lets go and change them when using the slider :)
jss = js"""
$(splot).then(plots=>{
    const scatter_plot = plots[0].plot_object
    console.log(scatter_plot)
    console.log($(s1.value))
    $(s1.value).on(new_value => {
        console.log(new_value)
        const news = [1,1,2,2,3,3,4,4].map(i => (i) + (new_value/10))
        scatter_plot.update([['positions_transformed_f32c', news]])
    })
    $(color_slider.value).on(hue => {
        console.log(hue)
        const color = new THREE.Color()
        color.setHSL(hue, 1.0, 0.5)
        scatter_plot.update([['uniform_color', [color.r, color.g, color.b, 1.0]]])
    })
    $(markersize.value).on(size => {
        console.log(size)
        scatter_plot.update([['quad_scale', [size, size]], ['quad_offset', [-size/2, -size/2]]])
    })
})
"""

DOM.div(s1, color_slider, markersize, fig, jss)
