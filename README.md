## Genetic Streetlight

This repository shows the source code used to generate an RShiny application Genetic Streetlight, which you can use at <http://whichgenesmatter.com>.

Genetic Streetlight takes in medical terminology search inputs and returns relevant genes and literature from a cached PostgreSQL database. The application identifies gene entities in PubMed articles, using a trained SpaCy model in Python, along with their contexts and links to respective PubMed articles. A count of the important genes is also displayed in a bar chart.

### SpaCy Model

You can also play with the trained SpaCy NER Model in a Docker container. Pull the image with the command:

```
docker pull nlin5/gene_hunter
```

Create a container named `geneapp` to be accessed on port 8000:

```
docker run --name geneapp -d -p 8000:5000 --rm nlin5/gene_hunter:latest
```

Now you can use `curl` to submit texts with gene names for the model to identify along with their index in the text. Here is an example input:

```
curl http://127.0.0.1:8000/get_entities -X POST \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -d '{
  "text": "my favorite genes are p53 and MDM2"
}'
```

And we get the result:

```
{
    "gene entities": [
        [
            "p53",
            22
        ],
        [
            "MDM2",
            30
        ]
    ]
}
```
