//
//  ViewController.m
//  ios-sdk-example
//
//  Created by Christopher Kleeschulte on 4/10/15.
//  Copyright (c) 2015 Christopher Kleeschulte. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (readonly) NSString *key;
@property (readonly) NSString *sin;
@property (readonly) NSString *token;
@property (readonly) NSString *signedMessage;
@property (readonly) NSString *invoice;
@property (nonatomic, strong) NSMutableData *responseData;
@end

@implementation ViewController

NSString *genericErrorMessage = @"There was an error from the api";
NSString const *bitpayUrl = @"https://test.bitpay.com";

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)generateKeys:(id)sender {
    _key = [KeyUtils generatePem];
    _keyText.text = _key;
    NSLog(@"pem key: %@", _key);
}

- (IBAction)generateSin:(id)sender {
    if(_key == nil) {
        _sinText.text = @"Please generate a key in the previous step first.";
    } else {
        _sin = [KeyUtils generateSinFromPem:_key];
        _sinText.text = _sin;
        NSLog(@"sin: %@", _sin);
    }
}

- (IBAction)getToken:(id)sender {

    if(_pairText.text == nil) {
        _tokenText.text = @"Please get a pairing code from test.bitpay.com";
    } else {
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: [NSURL URLWithString:[NSString stringWithFormat:@"%@/tokens", bitpayUrl]]];
        
        NSString *postString = [NSString stringWithFormat:@"id=%@&label=Test&pairingCode=%@", _sin, _pairText.text];

        [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
        [request setHTTPMethod:@"POST"];
        
        [NSURLConnection connectionWithRequest:request delegate:self];
    }
    
}

- (IBAction)testCreatInvoice:(id)sender {
    
    if(_token == nil || _key == nil || _sin == nil) {
        _invoiceText.text = @"Please geneate a key/sin/token before creating an invoice here.";
        return;
    }
    
    NSString *pubKey = [KeyUtils getPublicKeyFromPem:_key];
    NSLog(@"public key: %@", pubKey);
    NSLog(@"private key: %@", [KeyUtils getPrivateKeyFromPem:_key]);
    
    NSString *postString = [NSString stringWithFormat:@"{\"currency\":\"USD\",\"price\":20,\"token\":\"%@\"}", _token];
    
    NSString *message = [NSString stringWithFormat: @"https://test.bitpay.com/invoices%@", postString];
    
    _signedMessage = [KeyUtils sign:message withPem:_key];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: [NSURL URLWithString:[NSString stringWithFormat:@"%@/invoices", bitpayUrl]]];
    
    [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
    [request addValue:@"application/json" forHTTPHeaderField:@"content-type"];
    [request addValue:@"2.0.0" forHTTPHeaderField:@"x-accept-version"];
    [request addValue:pubKey forHTTPHeaderField:@"x-identity"];
    [request addValue:_signedMessage forHTTPHeaderField:@"x-signature"];
    [request setHTTPMethod:@"POST"];
    
    [NSURLConnection connectionWithRequest:request delegate:self];
    
}

#pragma mark NSURLConnection Delegate Methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _responseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_responseData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    NSError *error = nil;
    
    id object = [NSJSONSerialization
                 JSONObjectWithData:_responseData
                 options:0
                 error:&error];
    
    if(error) {
        _tokenText.text = genericErrorMessage;
    }
    
    if([object isKindOfClass:[NSDictionary class]]) {
        
        NSDictionary *results = object;
        NSString *error = [results objectForKey:@"error"];
        
        if(error) {
            NSLog(@"error: %@", error);
            _invoiceText.text = error;
            return;
        }
        
        NSDictionary *data = [results valueForKeyPath: @"data"];
        
        if(data) {
            id tokenId = [data valueForKeyPath: @"token"];
            if([tokenId isKindOfClass:[NSArray class]]) {
                NSArray *tokenArray = tokenId;
                _token = tokenArray[0];
                _tokenText.text = _token;
            }
            _invoiceText.text = [results description];
        } else {
            _invoiceText.text = [results description];
            NSLog(@"%@", [results description]);
            return;
        }
    }

}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"there was an error.");
}

@end
