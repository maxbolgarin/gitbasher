const https = require('https');
const fs = require('fs');
const path = require('path');

const VERSION = process.env.npm_package_version;
if (!VERSION) {
    console.error('Error: npm_package_version not found');
    process.exit(1);
}

// __dirname points to the package root when installed via npm
const BIN_DIR = path.join(__dirname, 'bin');
const BIN_PATH = path.join(BIN_DIR, 'gitb');
const RELEASE_URL = `https://github.com/maxbolgarin/gitbasher/releases/download/v${VERSION}/gitb`;

// Ensure bin directory exists
if (!fs.existsSync(BIN_DIR)) {
    fs.mkdirSync(BIN_DIR, { recursive: true });
}

// Download the release asset
console.log(`Downloading gitbasher v${VERSION} from GitHub releases...`);
const file = fs.createWriteStream(BIN_PATH);

https.get(RELEASE_URL, (response) => {
    if (response.statusCode === 302 || response.statusCode === 301) {
    // Follow redirect
    https.get(response.headers.location, (redirectResponse) => {
        redirectResponse.pipe(file);
        file.on('finish', () => {
        file.close();
        fs.chmodSync(BIN_PATH, 0o755);
        console.log('Download complete!');
        });
    });
    } else {
    response.pipe(file);
    file.on('finish', () => {
        file.close();
        fs.chmodSync(BIN_PATH, 0o755);
        console.log('Download complete!');
    });
    }
}).on('error', (err) => {
    fs.unlinkSync(BIN_PATH);
    console.error(`Error downloading release: ${err.message}`);
    process.exit(1);
});