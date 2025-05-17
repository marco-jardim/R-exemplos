import random, string, pandas as pd, numpy as np, datetime, uuid, os, math, tqdm


first_names = ["Maria", "Ana", "João", "José", "Paulo", "Francisco", "Carlos", "Luiz", "Lucas", "Marcos",
               "Gabriel","Mateus","Rafael","Clara","Júlia","Fernanda","Patrícia","Aline","Beatriz","Helena"]
last_names  = ["Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Almeida", "Costa", "Gomes", "Martins",
               "Barbosa","Ribeiro","Teixeira","Pereira","Correia","Melo","Carvalho","Araújo","Vieira","Pinto"]
sexes = ["F", "M"]

def random_name():
    return random.choice(first_names), random.choice(last_names)

def random_birth(start_year=1940, end_year=2005):
    year  = random.randint(start_year, end_year)
    month = random.randint(1, 12)
    day   = random.randint(1, 28)
    return f"{year:04d}-{month:02d}-{day:02d}"

def introduce_typo(text):
    if not text or len(text)==0:
        return text
    ops = ["swap", "delete", "insert", "space"]
    op = random.choice(ops)
    idx = random.randint(0, len(text)-1)
    if op=="swap" and len(text)>1:
        text = list(text)
        text[idx], text[(idx+1)%len(text)] = text[(idx+1)%len(text)], text[idx]
        return "".join(text)
    elif op=="delete":
        return text[:idx]+text[idx+1:]
    elif op=="insert":
        return text[:idx]+random.choice(string.ascii_letters)+text[idx:]
    elif op=="space":
        return text[:idx]+" "+text[idx:]
    return text

def maybe_missing(value, prob):
    return np.nan if random.random()<prob else value

def maybe_typo(text, prob):
    return introduce_typo(text) if random.random()<prob else text

def maybe_spaces(text, prob):
    if random.random() < prob:
        return " "+text+" "
    return text

def generate_dataset(n, year_label):
    ids = [f"{year_label}_{i+1}" for i in range(n)]
    firsts = random.choices(first_names, k=n)
    lasts  = random.choices(last_names,  k=n)
    dobs   = [random_birth() for _ in range(n)]
    sex    = random.choices(sexes, k=n)
    renda  = np.round(np.random.lognormal(mean=9, sigma=0.5, size=n),2)
    
    df = pd.DataFrame({
        "id": ids,
        "primeiro_nome": firsts,
        "sobrenome": lasts,
        "data_nasc": dobs,
        "sexo": sex,
        "renda": renda
    })
    # introduce noise vectorized
    mask_typo = np.random.rand(n) < 0.07
    df.loc[mask_typo, "primeiro_nome"] = df.loc[mask_typo, "primeiro_nome"].apply(introduce_typo)
    mask_typo2 = np.random.rand(n) < 0.07
    df.loc[mask_typo2, "sobrenome"] = df.loc[mask_typo2, "sobrenome"].apply(introduce_typo)
    
    mask_space = np.random.rand(n) < 0.1
    df.loc[mask_space, "primeiro_nome"] = " " + df.loc[mask_space, "primeiro_nome"] + " "
    mask_space2 = np.random.rand(n) < 0.1
    df.loc[mask_space2, "sobrenome"] = " " + df.loc[mask_space2, "sobrenome"] + " "
    
    df.loc[np.random.rand(n)<0.05, "primeiro_nome"] = np.nan
    df.loc[np.random.rand(n)<0.05, "sobrenome"] = np.nan
    df.loc[np.random.rand(n)<0.03, "data_nasc"] = np.nan
    df.loc[np.random.rand(n)<0.02, "sexo"] = np.nan
    df.loc[np.random.rand(n)<0.04, "renda"] = np.nan
    return df

# Generate 30k each
N = 30000
df2020 = generate_dataset(N, 2020)
df2021 = generate_dataset(N, 2021)

# Add overlap: copy 6000 records from 2020 with slight mods into 2021
overlap_n = 6000
sample_idx = np.random.choice(df2020.index, size=overlap_n, replace=False)
overlaps = df2020.loc[sample_idx].copy()
overlaps["id"] = [f"2021_clone_{i}" for i in range(overlap_n)]
# introduce slight noise
overlaps["renda"] = overlaps["renda"] * np.random.uniform(0.9, 1.1, size=overlap_n)
df2021 = pd.concat([df2021, overlaps], ignore_index=True)

# Save to CSV
os.makedirs("./bases", exist_ok=True)
path20 = "./bases/cadastro_2020.csv"
path21 = "./bases/cadastro_2021.csv"
df2020.to_csv(path20, index=False)
df2021.to_csv(path21, index=False)

print("Saved:")
print(path20)
print(path21)

