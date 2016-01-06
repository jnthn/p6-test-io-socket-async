use OO::Monitors;
no precompilation;

monitor Test::IO::Socket::Async {
    monitor Connection {
        has $.host;
        has $.port;
        has $.connection-promise = Promise.new;
        has $!connection-vow = $!connection-promise.vow;
        has @!sent;
        has @!waiting-sent-vows;
        has $!received = Supplier.new;

        method accept-connection() {
            $!connection-vow.keep(self);
        }

        method deny-connection($exception = "Connection refused") {
            $!connection-vow.break($exception);
        }

        method print(Str() $s) {
            @!sent.push($s);
            self!keep-sent-vows();
            self!kept-promise();
        }

        method write(Blob $b) {
            @!sent.push($b);
            self!keep-sent-vows();
            self!kept-promise();
        }

        method sent-data() {
            my $p = Promise.new;
            @!waiting-sent-vows.push($p.vow);
            self!keep-sent-vows();
            $p
        }

        method !keep-sent-vows() {
            while all(@!sent, @!waiting-sent-vows) {
                @!waiting-sent-vows.shift.keep(@!sent.shift);
            }
        }

        method !kept-promise() {
            my $p = Promise.new;
            $p.keep(True);
            $p
        }

        method Supply() {
            $!received.Supply
        }

        multi method receive-data(Str() $data) {
            $!received.emit($data);
        }
        multi method receive-data(Blob $data) {
            $!received.emit($data);
        }
    }

    has @!waiting-connects;
    has @!waiting-connection-made-vows;

    method connect(Str() $host, Int() $port) {
        my $conn = Connection.new(:$host, :$port);
        with @!waiting-connection-made-vows.shift {
            .keep($conn);
        }
        else {
            @!waiting-connects.push($conn);
        }
        $conn.connection-promise
    }

    method connection-made() {
        my $p = Promise.new;
        with @!waiting-connects.shift {
            $p.keep($_);
        }
        else {
            @!waiting-connection-made-vows.push($p.vow);
        }
        $p
    }
}
