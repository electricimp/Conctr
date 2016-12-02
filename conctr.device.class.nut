// Squirrel class to interface with the Conctr platform

// Copyright (c) 2016 Mystic Pants Pty Ltd
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class Conctr {

    static version = [1, 0, 0];

    // event to emit data payload
    static DATA_EVENT = "conctr_data";

    // 1 hour in milliseconds
    static HOUR_MS = 3600000;

    // Table parameters
    _locationRecording = true;
    _locationSent = false;
    _locationTimeout = 0;
    _interval = 0;
    _sendLocationOnce = false;

    // Callbacks
    _onResponse = null;

    /**
     * Constructor for Conctr
     * 
     * @param opts - location recording options 
     * {
     *   {Boolean}  isEnabled - Should location be sent with data
     *   {Integer}  interval - Duration in milliseconds since last location update to wait before sending a new location
     *   {Boolean}  sendOnce - Setting to true sends the location of the device only once when the device restarts 
     *  }
     *
     * NOTE: isEnabled takes precedence over sendOnce. Meaning if isEnabled is set to false location will never be sent 
     *       with the data until this flag is changed.
     */
    constructor(opts = null) {

        if (opts != null) setOpts(opts);
        _locationTimeout = hardware.millis();
        _onResponse = {};

        agent.on(DATA_EVENT, _doResponse.bindenv(this));
    }


    /**
     * Funtion to set location recording options
     * 
     * @param opts {Table} - location recording options 
     * {
     *   {Boolean}  isEnabled - Should location be sent with data
     *   {Integer}  interval - Duration in milliseconds since last location update to wait before sending a new location
     *   {Boolean}  sendOnce - Setting to true sends the location of the device only once when the device restarts 
     *  }
     *
     * NOTE: isEnabled takes precedence over sendOnce. Meaning if isEnabled is set to false location will never be sent 
     *       with the data until this flag is changed.
     */
    function setOpts(opts) {

        _interval = ("interval" in opts && opts.interval != null) ? opts.interval : HOUR_MS; // set default interval between location updates
        _sendLocationOnce = ("sendOnce" in opts && opts.sendOnce != null) ? opts.sendOnce : null;

        _locationRecording = opts.isEnabled;
        _locationTimeout = hardware.millis();
        _locationSent = false;

        // TODO finish this. enabled only sends location every time, interval only sends it if the data update is
        // after a certain interval since the last on and sendOnce only sends it once till device is rebooted

    }


    /**
     * @param  {Table} payload - Table containing data to be persisted
     * @param  { {Function (err,response)} callback - Callback function on resp from Conctr through agent
     */
    function sendData(payload, callback = null) {

        if (typeof payload != "table") {
            throw "Conctr: Payload must contain a table";
        }

        // set timestamp to now if not already set
        if (!("_ts" in payload) || (payload._ts == null)) {
            payload._ts < -time();
        }

        // Add an unique id for tracking the response
        payload._id < -format("%d:%d", hardware.millis(), hardware.micros());

        _getWifis(function(wifis) {

            if ((wifis != null) && !("_location" in payload)) {
                payload._location < -wifis;
            }

            // Todo: Add optional Bullwinkle here
            // Store the callback for later
            if (callback) _onResponse[payload._id] < -callback;
            agent.send("conctr_data", payload);
        });

    }


    /**
     * Responds to callback associated with (callback) ids in response from agent
     *
     * @param response {Table} - response for callback from agent - 
     * {
     *     {String}  id - id of the callback that was stored in _onResponse
     *     {Table}   error - error response from agent
     *     {Boolean} body - response body from agent 
     * }
     * 
     */
    function _doResponse(response) {
        foreach(id in response.ids) {
            if (id in _onResponse) {
                _onResponse[id](response.error, response.body);
            }
        }
    }



    /**
     * Checks current location recording options and calls the callback function with either currently available
     * wifis or null fullfilment of current conditions based on current options
     * 
     * @param  {Function} callback - called with wifi result 
     * @return {onSuccess([Objects])} - Array of wifi objects
     *
     */
    function _getWifis(callback) {

        if (!_locationRecording) {

            // not recording location 
            return callback(null);

        } else {

            // check new location scan conditions are met and search for proximal wifi networks
            if ((_sendLocationOnce != null) && (_locationSent == false) || ((_sendLocationOnce == null) && (_locationRecording == true) && (_locationTimeout < hardware.millis()))) {

                local wifis = imp.scanwifinetworks();

                // update timeout 
                _locationTimeout = hardware.millis() + _interval;
                _locationSent = true;

                return callback(wifis);

            } else {

                // conditions for new location search (using wifi networks) not met
                return callback(null);

            }
        }
    }
}