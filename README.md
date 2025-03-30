<img src="https://user-images.githubusercontent.com/1223300/62239305-eb156f80-b3d4-11e9-8d3f-289b1800987a.png" width="100">

# Jello

A wobbly windows implementation for MacOS inspired by [Compiz](http://www.compiz.org/) for Linux. 

<sup>*Note: this is only a proof of concept, I am not actively maintaining the project. It may not always be stable, but I am open to contributions :)*</sup>

https://user-images.githubusercontent.com/1223300/147920756-0fe92886-6c1f-4351-af43-e3c90741f571.mp4

For a demo injected into MacOS, check out [this video](https://youtu.be/G4qud4ySnb8).

## Usage

- Install SIMBL loader like using [mySIMBL](https://github.com/w0lfschild/mySIMBL) or [MacForge](https://www.macenhance.com/macforge). Note that you currently need to disable System Integrity Protection (SIP) in order for this to work.
- Download the [latest bundle](https://github.com/iamDecode/Jello/releases), or build it yourself (see Building).
- Drag bundle onto the app to enable it.
- Restart apps for Jello to take effect.


## Building

The Xcode project contains two targets, `Jello` will run a sample window with wobble logic enabled, `JelloInject` builds a bundle that can be used with a SIMBL loader.


## Contributing

Feel free to make a contribution. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on the code of conduct, and the process for submitting pull requests.

## License

This project is licensed under the BSD 2-Clause License - see the [LICENSE](LICENSE) file for details.
