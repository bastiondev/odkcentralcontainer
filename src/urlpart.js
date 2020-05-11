const { URL } = require('url');

// Gets the requested part of the URI, used to parse DATABASE_URL variable
// into the DATABASE__* variables to create config.json
const getUrlPart = (string, part) => {

  const uri = new URL(string);

  // Remove leading slash from path (we want DB name)
  process.stdout.write(part === 'pathname' ? 
    uri[part].replace(/\//, '') : 
    uri[part]
  );
}  

module.exports = { getUrlPart };
