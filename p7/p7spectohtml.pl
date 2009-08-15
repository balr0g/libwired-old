#!/usr/bin/perl

use strict;
use XML::Parser;
use Data::Dumper;


sub main {
	my($file) = @_;

	my $parser = XML::Parser->new(Style => "Tree");
	my $tree = $parser->parsefile($file);

	my $protocol = $tree->[1];
	my $info = $protocol->[0];

	my @fields;
	my %fields;
	my %collections;
	my @messages;
	my @transactions;
	my @broadcasts;

	for(my $i = 0; $i < @$protocol; $i++) {
		my $node = $protocol->[$i];

		if($node eq "p7:documentation") {
			$info->{"documentation"} = documentation($protocol->[$i + 1]->[2]);
		}
		elsif($node eq "p7:fields") {
			for(my $j = 0; $j < @{$protocol->[$i + 1]}; $j++) {
				if($protocol->[$i + 1]->[$j] eq "p7:field") {
					my $fieldnode = $protocol->[$i + 1]->[$j + 1];
					my $field = $fieldnode->[0];

					my @enums;

					for(my $k = 0; $k < @{$fieldnode}; $k++) {
						if($fieldnode->[$k] eq "p7:enum") {
							push(@enums, $fieldnode->[$k + 1]->[0]);
						}
						elsif($fieldnode->[$k] eq "p7:documentation") {
							$field->{"documentation"} = documentation($fieldnode->[$k + 1]->[2]);
						}
					}

					$field->{"enums"} = \@enums;
					$field->{"type"} = type($field->{"type"});

					$fields{$field->{"name"}} = $field;

					push(@fields, $field);
				}
			}
		}
		elsif($node eq "p7:collections") {
			for(my $j = 0; $j < @{$protocol->[$i + 1]}; $j++) {
				if($protocol->[$i + 1]->[$j] eq "p7:collection") {
					my $collectionnode = $protocol->[$i + 1]->[$j + 1];
					my $collection = $collectionnode->[0];

					my @fields;

					for(my $k = 0; $k < @{$collectionnode}; $k++) {
						if($collectionnode->[$k] eq "p7:member") {
							push(@fields, $collectionnode->[$k + 1]->[0]->{"field"});
						}
					}

					$collections{$collection->{"name"}} = \@fields;
				}
			}
		}
		elsif($node eq "p7:messages") {
			for(my $j = 0; $j < @{$protocol->[$i + 1]}; $j++) {
				if($protocol->[$i + 1]->[$j] eq "p7:message") {
					my $messagenode = $protocol->[$i + 1]->[$j + 1];
					my $message = $messagenode->[0];

					my @required_parameters;
					my @optional_parameters;

					for(my $k = 0; $k < @{$messagenode}; $k++) {
						if($messagenode->[$k] eq "p7:parameter") {
							my $optional = 0;

							if(!$messagenode->[$k + 1]->[0]->{"use"} || $messagenode->[$k + 1]->[0]->{"use"} eq "optional") {
								$optional = 1;
							}

							foreach my $parameter ($messagenode->[$k + 1]->[0]) {
								my $fields = $collections{$parameter->{"collection"}};

								if($fields) {
									foreach my $field (@$fields) {
										my $collection_parameter;

										$collection_parameter->{"field"} = $fields{$field};
										$collection_parameter->{"version"} = $parameter->{"version"};

										if($optional) {
											push(@optional_parameters, $collection_parameter);
										} else {
											push(@required_parameters, $collection_parameter);
										}
									}
								} else {
									$parameter->{"field"} = $fields{$parameter->{"field"}};

									if($optional) {
										push(@optional_parameters, $parameter);
									} else {
										push(@required_parameters, $parameter);
									}
								}
							}
						}
						elsif($messagenode->[$k] eq "p7:documentation") {
							$message->{"documentation"} = documentation($messagenode->[$k + 1]->[2]);
						}
					}

					$message->{"required_parameters"} = \@required_parameters;
					$message->{"optional_parameters"} = \@optional_parameters;

					push(@messages, $message);
				}
			}
		}
		elsif($node eq "p7:transactions") {
			for(my $j = 0; $j < @{$protocol->[$i + 1]}; $j++) {
				if($protocol->[$i + 1]->[$j] eq "p7:transaction") {
					my $transactionnode = $protocol->[$i + 1]->[$j + 1];
					my $transaction = $transactionnode->[0];

					my @replies;
					my $index1 = 0;
					my $index2 = 0;

					for(my $k = 0; $k < @{$transactionnode}; $k++) {
						if($transactionnode->[$k] =~ /^p7:reply|p7:and|p7:or/) {
							my $replynode = $transactionnode->[$k + 1];

							if($transactionnode->[$k] eq "p7:or") {
								for(my $l = 0; $l < @{$replynode}; $l++) {
									$index2 = 0;

									if($replynode->[$l] eq "p7:and") {
										for(my $m = 0; $m < @{$replynode->[$l + 1]}; $m++) {
											if($replynode->[$l + 1]->[$m] eq "p7:reply") {
												$replies[$index1]->[$index2] = $replynode->[$l + 1]->[$m + 1]->[0];
												$index2++;
											}
										}

										$index1++;
									}
									elsif($replynode->[$l] eq "p7:reply") {
										$replies[$index1]->[$index2] = $replynode->[$l + 1]->[0];
										$index1++;
									}
								}
							}
							elsif($transactionnode->[$k] eq "p7:reply") {
								$replies[$index1]->[$index2] = $replynode->[0];

								$index2++;
							}
						}
						elsif($transactionnode->[$k] eq "p7:documentation") {
							$transaction->{"documentation"} = documentation($transactionnode->[$k + 1]->[2]);
						}
					}

					$transaction->{"originator"} = originator($transaction->{"originator"});
					$transaction->{"replies"} = \@replies;

					push(@transactions, $transaction);
				}
			}
		}
		elsif($node eq "p7:broadcasts") {
			for(my $j = 0; $j < @{$protocol->[$i + 1]}; $j++) {
				if($protocol->[$i + 1]->[$j] eq "p7:broadcast") {
					my $broadcastnode = $protocol->[$i + 1]->[$j + 1];
					my $broadcast = $broadcastnode->[0];

					for(my $k = 0; $k < @{$broadcastnode}; $k++) {
						if($broadcastnode->[$k] eq "p7:documentation") {
							$broadcast->{"documentation"} = documentation($broadcastnode->[$k + 1]->[2]);
						}
					}

					push(@broadcasts, $broadcast);
				}
			}
		}
	}

	printheader($info, \@fields, \@messages, \@transactions, \@broadcasts);
	printfields(\@fields);
	printmessages(\@messages);
	printtransactions(\@transactions);
	printbroadcasts(\@broadcasts);
	printfooter();
}


sub documentation {
	my($documentation) = @_;

	$documentation =~ s/ +/ /g;
	$documentation =~ s/\t+/\t/g;
	$documentation =~ s/^[ \t]//mg;
	$documentation =~ s/[ \t]$//mg;
	$documentation =~ s/\n\n/<br \/>\n<br \/>\n/g;

	$documentation =~ s/\[field:(.+?)\]/<a href="#field,\1">\1<\/a>/g;
	$documentation =~ s/\[enum:(.+?)\]/<a href="#enum,\1">\1<\/a>/g;
	$documentation =~ s/\[message:(.+?)\]/<a href="#message,\1">\1<\/a>/g;
	$documentation =~ s/\[broadcast:(.+?)\]/<a href="#broadcast,\1">\1<\/a>/g;

	return $documentation;
}


sub type {
	my($type) = @_;

	return "Boolean" if $type eq "bool";
	return "Enumerated value" if $type eq "enum";
	return "Signed 32-bit integer" if $type eq "int32";
	return "Unsigned 32-bit integer" if $type eq "uint32";
	return "Signed 64-bit integer" if $type eq "int64";
	return "Unsigned 64-bit integer" if $type eq "uint64";
	return "Floating Point number" if $type eq "double";
	return "String" if $type eq "string";
	return "UUID" if $type eq "uuid";
	return "Date" if $type eq "date";
	return "Data" if $type eq "data";
	return "Out-of-band data" if $type eq "oobdata";
	return "List" if $type eq "list";
}


sub originator {
	my($type) = @_;

	return "Client" if $type eq "client";
	return "Server" if $type eq "server";
	return "Both" if $type eq "both";
}


sub printheader {
	my($info, $fields, $messages, $transactions, $broadcasts) = @_;

	print <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<!-- baka baka minna baka -->
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	<title>Zanka Software</title>
	<link rel="stylesheet" type="text/css" href="http://www.zankasoftware.com/css/index.css">
</head>
<body>

<span class="largetitle">$info->{"name"} $info->{"version"}</span>

<br />
<br />

$info->{"documentation"}

<br />
<br />

<span class="mediumtitle">Fields</span><br />

<blockquote>
EOF

	foreach my $field (@$fields) {
		print <<EOF;
<a href="#field,$field->{"name"}">$field->{"name"}</a><br />
EOF
	}

	print <<EOF;
</blockquote>

<br />
<br />

<span class="mediumtitle">Messages</span><br />

<blockquote>
EOF

	foreach my $message (@$messages) {
		print <<EOF;
<a href="#message,$message->{"name"}">$message->{"name"}</a><br />
EOF
	}

	print <<EOF;
</blockquote>

<br />
<br />

<span class="mediumtitle">Transactions</span><br />

<blockquote>
EOF

	foreach my $transaction (@$transactions) {
		print <<EOF;
<a href="#transaction,$transaction->{"message"}">$transaction->{"message"}</a><br />
EOF
	}

	print <<EOF;
</blockquote>

<br />
<br />

<span class="mediumtitle">Broadcasts</span><br />

<blockquote>
EOF

	foreach my $broadcast (@$broadcasts) {
		print <<EOF;
<a href="#broadcast,$broadcast->{"message"}">$broadcast->{"message"}</a><br />
EOF
	}

	print <<EOF;
</blockquote>
<br />
<br />
<br />
EOF
}



sub printfields {
	my($fields) = @_;

	print <<EOF;
<a class="largetitle" name="fields">Fields</span>

<br />
<br />
EOF

	foreach my $field (@$fields) {
		print <<EOF;
<a name="field,$field->{"name"}"><span class="mediumtitle">$field->{"name"}</span></a>

<br />
<br />

$field->{"documentation"}

<br />
<br />

<b>ID</b><br />
$field->{"id"}

<br />
<br />

<b>Type</b><br />
$field->{"type"}

<br />
<br />
EOF

		if($field->{"type"} eq "list") {
			print <<EOF;
<br />
<br />

<b>List Type</b><br />
$field->{"listtype"}

<br />
<br />

EOF
		}

		if(@{$field->{"enums"}} > 0) {
			print <<EOF;
<b>Values</b><br />
EOF

			foreach my $enum (@{$field->{"enums"}}) {
				print <<EOF;
<a name="enum,$enum->{"name"}">$enum->{"name"} = $enum->{"value"}</a><br />
<blockquote>Available in version $enum->{"version"} and later.</blockquote>
EOF
			}

			print <<EOF;
<br />
EOF
		}

		print <<EOF;
<b>Availability</b><br />
Available in version $field->{"version"} and later.

<br />
<br />
<br />
EOF
	}

	print <<EOF;
<br />
EOF
}



sub printmessages {
	my($messages) = @_;

	print <<EOF;
<a class="largetitle" name="messages">Messages</span>

<br />
<br />
EOF

	foreach my $message (@$messages) {
		print <<EOF;
<a name="message,$message->{"name"}"><span class="mediumtitle">$message->{"name"}</span></a>

<br />
<br />

$message->{"documentation"}

<br />
<br />

<b>ID</b><br />
$message->{"id"}

<br />
<br />
EOF

		if(@{$message->{"required_parameters"}} > 0) {
			print <<EOF;
<b>Required Parameters</b><br />
EOF

			printparameters($message->{"required_parameters"});

			print <<EOF;
<br />
EOF
		}

		if(@{$message->{"optional_parameters"}} > 0) {
			print <<EOF;
<b>Optional Parameters</b><br />
EOF

			printparameters($message->{"optional_parameters"});

			print <<EOF;
<br />
EOF
		}

		print <<EOF;
<b>Availability</b><br />
Available in version $message->{"version"} and later.

<br />
<br />
<br />
EOF
	}

	print <<EOF;
<br />
EOF
}



sub printparameters {
	my($parameters) = @_;

	foreach my $parameter (@$parameters) {
		print <<EOF;
<a href="#field,$parameter->{"field"}->{"name"}">$parameter->{"field"}->{"name"}</a><br />
<blockquote>Available in version $parameter->{"version"} and later.</blockquote>
EOF
	}
}



sub printtransactions {
	my($transactions) = @_;

	print <<EOF;
<a class="largetitle" name="transactions">Transactions</span>

<br />
<br />
EOF

	foreach my $transaction (@$transactions) {
		print <<EOF;
<a name="transaction,$transaction->{"message"}"><span class="mediumtitle">$transaction->{"message"}</span></a>

<br />
<br />

$transaction->{"documentation"}

<br />
<br />

<b>Message</b><br />
<a href="#message,$transaction->{"message"}">$transaction->{"message"}</a>

<br />
<br />

<b>Originator</b><br />
$transaction->{"originator"}

<br />
<br />

<b>Replies</b><br />
EOF

		my $replies1 = $transaction->{"replies"};

		for(my $index1 = 0; $index1 < @$replies1; $index1++) {
			my $replies2 = $replies1->[$index1];

			for(my $index2 = 0; $index2 < @$replies2; $index2++) {
				my $reply = $replies1->[$index1]->[$index2];
				my $count;

				if($reply->{"count"} eq "?") {
					$count = "Zero or one";
				}
				elsif($reply->{"count"} eq "*") {
					$count = "Zero or more";
				}
				elsif($reply->{"count"} eq "+") {
					$count = "One or more";
				}
				elsif($reply->{"count"} eq "1") {
					$count = "One";
				}
				else {
					$count = $reply->{"count"};
				}

				print <<EOF;
$count <a href="#message,$reply->{"message"}">$reply->{"message"}</a><br />
EOF
			}

			if($index1 < @$replies1 - 1) {
				print <<EOF;
<i>or</i><br />
EOF
			}
		}

		print <<EOF;
<br />

<b>Availability</b><br />
Available in version $transaction->{"version"} and later.

<br />
<br />
<br />
EOF
	}

	print <<EOF;
<br />
EOF
}



sub printbroadcasts {
	my($broadcasts) = @_;

	print <<EOF;
<a class="largetitle" name="broadcasts">Broadcasts</span>

<br />
<br />

EOF

	foreach my $broadcast (@$broadcasts) {
		print <<EOF;
<a name="broadcast,$broadcast->{"message"}"><span class="mediumtitle">$broadcast->{"message"}</span></a>

<br />
<br />

$broadcast->{"documentation"}

<br />
<br />

<b>Message</b><br />
<a href="#message,$broadcast->{"message"}">$broadcast->{"message"}</a><br />
EOF

		print <<EOF;
<br />

<b>Availability</b><br />
Available in version $broadcast->{"version"} and later.
EOF

		if($broadcast != $broadcasts->[-1]) {
			print <<EOF;
<br />
	<br />
<br />
EOF
		}
	}
}



sub printfooter {
	print <<EOF;
</body>
</html>
EOF
}



main($ARGV[0]);
