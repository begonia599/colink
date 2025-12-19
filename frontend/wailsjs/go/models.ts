export namespace main {
	
	export class ConnectionStatus {
	    connected: boolean;
	    localPort: number;
	    error?: string;
	
	    static createFrom(source: any = {}) {
	        return new ConnectionStatus(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.connected = source["connected"];
	        this.localPort = source["localPort"];
	        this.error = source["error"];
	    }
	}
	export class NodeConfig {
	    server: string;
	    port: number;
	    key: string;
	    crypt: string;
	    mode: string;
	    localPort: number;
	
	    static createFrom(source: any = {}) {
	        return new NodeConfig(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.server = source["server"];
	        this.port = source["port"];
	        this.key = source["key"];
	        this.crypt = source["crypt"];
	        this.mode = source["mode"];
	        this.localPort = source["localPort"];
	    }
	}

}

