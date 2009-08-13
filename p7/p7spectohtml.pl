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
	my %collections;
	my @messages;
	my @transactions;
	my @broadcasts;
	
	for(my $i = 0; $i < @$protocol; $i++) {
		my $node = $protocol->[$i];
		my $index = 0;
		
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
					$field->{"number"} = ++$index;

					push(@fields, $field);
				}
			}
		}
		elsif($node eq "p7:collections") {
			for(my $j = 0; $j < @{$protocol->[$i + 1]}; $j++) {
				if($protocol->[$i + 1]->[$j] eq "p7:collection") {
					my $collectionnode = $protocol->[$i + 1]->[$j + 1];
					my $collection = $collectionnode->[0];

					my @members;

					for(my $k = 0; $k < @{$collectionnode}; $k++) {
						if($collectionnode->[$k] eq "p7:member") {
							push(@members, $collectionnode->[$k + 1]->[0]);
						}
					}

					$collections{$collection->{"name"}} = \@members;
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
							my @parameters;
							my $collection = $collections{$messagenode->[$k + 1]->[0]->{"collection"}};
							
							if($collection) {
								@parameters = @{$collection};
							} else {
								@parameters = ($messagenode->[$k + 1]->[0]);
							}
							
							if(!$messagenode->[$k + 1]->[0]->{"use"} || $messagenode->[$k + 1]->[0]->{"use"} eq "optional") {
								foreach my $parameter (@parameters) {
									push(@optional_parameters, $parameter);
								}
							} else {
								foreach my $parameter (@parameters) {
									push(@required_parameters, $parameter);
								}
							}
						}
						elsif($messagenode->[$k] eq "p7:documentation") {
							$message->{"documentation"} = documentation($messagenode->[$k + 1]->[2]);
						}
					}
					
					$message->{"required_parameters"} = \@required_parameters;
					$message->{"optional_parameters"} = \@optional_parameters;
					$message->{"number"} = ++$index;

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
					
					$transaction->{"replies"} = \@replies;
					$transaction->{"number"} = ++$index;
					
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

					$broadcast->{"number"} = ++$index;

					push(@broadcasts, $broadcast);
				}
			}
		}
	}
	
	printheader($info);
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


sub printheader {
	my($info) = @_;
	
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

<small>
<a href="#fields">1 Fields</a><br />
<a href="#messages">2 Messages</a><br />
<a href="#transactions">3 Transactions</a><br />
<a href="#broadcasts">4 Broadcasts</a><br />
</small>
	
<br />
	
$info->{"documentation"}
	
<br />
<br />
EOF
}



sub printfields {
	my($fields) = @_;
	
	print <<EOF;
<a class="largetitle" name="fields">1 Fields</span>
	
<br />
<br />
EOF
	
	foreach my $field (@$fields) {
		print <<EOF;
<a name="field,$field->{"name"}"><span class="mediumtitle">1.$field->{"number"} $field->{"name"}</span></a>
		
<br />
<br />

ID: $field->{"id"}<br />
Type: $field->{"type"} <br />
EOF
		
		if($field->{"type"} eq "list") {
			print <<EOF;
List Type: $field->{"listtype"} <br />
EOF
		}
		
		if(@{$field->{"enums"}} > 0) {
			print <<EOF;
Values:

<br />
<br />
			
<ul>
EOF
			
			foreach my $enum (@{$field->{"enums"}}) {
				print <<EOF;
<li><a name="enum,$enum->{"name"}">$enum->{"name"}: $enum->{"value"}</a></li>
EOF
			}
			
			print <<EOF;
</ul>
EOF
		}
		
		if($field->{"documentation"}) {
			print <<EOF;
<br />
		
$field->{"documentation"}
EOF
		}
	
		print <<EOF;
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
<a class="largetitle" name="messages">2 Messages</span>
	
<br />
<br />
EOF
	
	foreach my $message (@$messages) {
		print <<EOF;
<a name="message,$message->{"name"}"><span class="mediumtitle">2.$message->{"number"} $message->{"name"}</span></a>
		
<br />
<br />

ID: $message->{"id"}<br />
EOF
		
		if(@{$message->{"required_parameters"}} > 0) {
			print <<EOF;
Required parameters:

<br />
<br />
EOF
		
			printparameters($message->{"required_parameters"});
		}
		
		if(@{$message->{"optional_parameters"}} > 0) {
			print <<EOF;
Optional parameters:

<br />
<br />
EOF
		
			printparameters($message->{"optional_parameters"});
		}
		
		if($message->{"documentation"}) {
			print <<EOF;
$message->{"documentation"}
EOF
		}
	
		print <<EOF;
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

	print <<EOF;
<ul>
EOF
			
	foreach my $parameter (@$parameters) {
		if($parameter->{"field"}) {
			print <<EOF;
<li><a href="#field,$parameter->{"field"}">$parameter->{"field"}</a></li>
EOF
		}
		elsif($parameter->{"collection"}) {
			print <<EOF;
<li><a href="#collection,$parameter->{"collection"}">$parameter->{"collection"}</a></li>
EOF
		}
	}
		
	print <<EOF;
</ul>
<br />
EOF
}



sub printtransactions {
	my($transactions) = @_;
	
	print <<EOF;
<a class="largetitle" name="transactions">3 Transactions</span>
	
<br />
<br />
EOF
	
	foreach my $transaction (@$transactions) {
		print <<EOF;
<a name="transaction,$transaction->{"message"}"><span class="mediumtitle">3.$transaction->{"number"} $transaction->{"message"}</span></a>
		
<br />
<br />

Message: <a href="#message,$transaction->{"message"}">$transaction->{"message"}</a><br />
Originator: $transaction->{"originator"}<br />
Replies:

<br />
<br />
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
				else {
					$count = "Exactly " . $reply->{"count"};
				}
				
				print <<EOF;
<li>$count <a href="#message,$reply->{"message"}">$reply->{"message"}</a></li>
EOF
			}
			
			if($index1 < @$replies1 - 1) {
				print <<EOF;
<br />
or
<br />
<br />
EOF
			}
		}
		
		print <<EOF;
<br />

$transaction->{"documentation"}

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
<a class="largetitle" name="broadcasts">4 Broadcasts</span>
	
<br />
<br />
EOF
	
	foreach my $broadcast (@$broadcasts) {
		print <<EOF;
<a name="broadcast,$broadcast->{"message"}"><span class="mediumtitle">4.$broadcast->{"number"} $broadcast->{"message"}</span></a>
		
<br />
<br />

Message: <a href="#message,$broadcast->{"message"}">$broadcast->{"message"}</a><br />
EOF
		
		print <<EOF;
<br />

$broadcast->{"documentation"}
EOF

		if($broadcast != $broadcasts->[-1]) {
			print <<EOF;
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
