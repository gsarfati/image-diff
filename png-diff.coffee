fs            = require 'fs'
PNG           = require('pngjs').PNG
EventEmitter  = require('events').EventEmitter

extractRGBA = (color) ->
  color = parseInt color
  rgba =
    r: (color >>> 16) & 0xFF
    g: (color >>>  8) & 0xFF
    b: (color >>>  0) & 0xFF
    a: (color >>> 24) & 0xFF

fillPixel = (img, pixel, color) ->
  img[pixel]   = color.r
  img[pixel+1] = color.g
  img[pixel+2] = color.b
  img[pixel+3] = color.a

pngDiff = (params) ->

  comparaison =  new EventEmitter()

  if params.tolerance is undefined then params.tolerance = 0
  if params.fgColor is undefined then params.fgColor = extractRGBA 0xFFFF0000
  
  # Count of pixel not match
  pixelNotMatch = 0

  # Percent of image are equal
  percentMatch = 0

  # Read Img
  expectedImg = new PNG().parse(fs.readFileSync(params.expected))

  fs.createReadStream(params.current).pipe(new PNG { filterType: 4 })

  .on 'parsed', ->
    currentImg = this
    console.log -1 if (expectedImg.height isnt currentImg.height) or (expectedImg.width isnt currentImg.width)

    # Compare pixel by pixel
    for y in [0..expectedImg.height]
      for x in [0..expectedImg.width]
        pixel = (expectedImg.width * y + x) << 2

        # If pixel color is equal or similar (params.tolerance)
        if  Math.abs(currentImg.data[pixel] - expectedImg.data[pixel]) <= params.tolerance and
            Math.abs(currentImg.data[pixel + 1] - expectedImg.data[pixel + 1]) <= params.tolerance and
            Math.abs(currentImg.data[pixel + 2] - expectedImg.data[pixel + 2]) <= params.tolerance and
            Math.abs(currentImg.data[pixel + 3] - expectedImg.data[pixel + 3]) <= params.tolerance

          if params.bgColor isnt undefined then fillPixel currentImg.data, pixel, params.bgColor
          else currentImg.data[pixel+3] = expectedImg.data[pixel+3] >> 1

        else
          fillPixel currentImg.data, pixel, params.fgColor
          pixelNotMatch++

    percent = ~~(100 - (100 / (expectedImg.height * expectedImg.width) * pixelNotMatch))

    # Create folder if not exist
    pathFolder = params.output.replace /// [\w]*.png$ ///, ''
    if pathFolder isnt '' and !fs.existsSync pathFolder
      fs.mkdirSync pathFolder

    # Write new Image Diff at output
    currentImg
    .pack()
    .pipe fs.createWriteStream params.output

    event = if pixelNotMatch is 0 then 'isEqual' else 'isNotEqual'

    comparaison.emit event,
      pixelNotMatch: pixelNotMatch
      percentMatch: percentMatch

  comparaison

exports.pngDiff = pngDiff
